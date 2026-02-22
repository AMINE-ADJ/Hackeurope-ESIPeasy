# app/jobs/grid_monitor_job.rb
#
# Runs every 5 minutes to orchestrate the full monitoring cycle:
# 1. Ingest fresh grid data for all zones
# 2. Run the incident agent (anomaly detection, health checks, migrations, slicing)
# 3. Trigger curtailment alerts
# 4. Route pending workloads via tiered Smart Broker
# 5. Checkpoint running workloads & check for reroutes
#
class GridMonitorJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[GridMonitor] Starting full monitoring cycle")

    # 1. Ingest fresh grid data
    GridDataService.ingest_all_zones!

    # 2. Run adaptive agent (includes health checks, GPU slicing, compliance)
    IncidentAgentService.monitor_and_adapt!

    # 3. Trigger unalerted curtailment events
    CurtailmentEvent.active.unalerted.find_each do |event|
      event.trigger_alert!
    end

    # 4. Route any pending workloads through tiered broker
    Workload.needs_routing.find_each do |workload|
      BrokerAgentService.new(workload).route!
    end

    # 5. Checkpoint running workloads & check for reroutes
    CheckpointService.checkpoint_all_due!
    BrokerAgentService.check_all_running_workloads!

    Rails.logger.info("[GridMonitor] Full cycle complete")
  end
end
