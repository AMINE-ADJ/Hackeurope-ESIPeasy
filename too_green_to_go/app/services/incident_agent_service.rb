# app/services/incident_agent_service.rb
#
# incident.io Adaptable Agent Pattern Implementation
#
# The "Broker Agent" — the brain of the routing system.
# This service wraps the BrokerAgentService with incident.io-style
# adaptive behavior:
#
# 1. DETECT: Continuously monitors grid conditions
# 2. DECIDE: Evaluates if current routing is still optimal
# 3. ADAPT: Takes corrective action (pause, reroute, escalate)
# 4. LEARN: Logs all decisions for future optimization
#
# State Machine:
#   MONITORING -> ANOMALY_DETECTED -> EVALUATING -> ADAPTING -> MONITORING
#
class IncidentAgentService
  STATES = %w[monitoring anomaly_detected evaluating adapting resolved].freeze

  ANOMALY_THRESHOLDS = {
    carbon_spike_pct: 50,        # >50% increase triggers reroute
    price_surge_pct: 100,        # >100% price increase
    renewable_drop_pct: 30,      # >30% renewable drop
    curtailment_threshold_mw: 200 # New opportunity
  }.freeze

  attr_reader :state, :incidents, :workload

  def initialize(workload = nil)
    @workload = workload
    @state = "monitoring"
    @incidents = []
  end

  # === Main monitoring loop (called by GridMonitorJob) ===
  def self.monitor_and_adapt!
    active_workloads = Workload.active.includes(:compute_node, :routing_decisions)
    grid_anomalies = detect_grid_anomalies

    Rails.logger.info("[IncidentAgent] Monitoring #{active_workloads.count} workloads, #{grid_anomalies.count} anomalies detected")

    grid_anomalies.each do |anomaly|
      affected = active_workloads.select { |w| w.compute_node&.grid_zone == anomaly[:zone] }
      affected.each do |workload|
        agent = new(workload)
        agent.handle_anomaly!(anomaly)
      end
    end

    # Check for new surplus opportunities (Crusoe model)
    check_surplus_opportunities!

    # Health-check all active nodes & trigger migrations
    HealthCheck.check_all_nodes!
    CheckpointService.check_and_migrate!

    # Auto-manage GPU slices on underutilized nodes
    GpuSlicingService.auto_manage!

    # Update green compliance for all nodes
    GreenComplianceEngine.update_all_compliance!

    # Snapshot dynamic pricing
    DynamicPricingService.snapshot_all!
  end

  def handle_anomaly!(anomaly)
    transition_to!("anomaly_detected")
    log_incident("anomaly_detected", anomaly)

    transition_to!("evaluating")
    action = evaluate_response(anomaly)

    transition_to!("adapting")
    execute_action!(action, anomaly)

    transition_to!("resolved")
    log_incident("resolved", { action: action, anomaly: anomaly })
  end

  private

  def evaluate_response(anomaly)
    case anomaly[:type]
    when :carbon_spike
      workload.green_only? ? :reroute : :monitor
    when :price_surge
      workload.priority == "async" ? :reroute : :alert
    when :renewable_drop
      workload.green_only? ? :pause_and_reroute : :monitor
    when :curtailment_opportunity
      :opportunistic_route
    else
      :monitor
    end
  end

  def execute_action!(action, anomaly)
    case action
    when :reroute
      BrokerAgentService.new(workload).reroute!(reason: anomaly[:type].to_s)
    when :pause_and_reroute
      workload.pause!(reason: anomaly[:type].to_s)
      BrokerAgentService.new(workload).reroute!(reason: anomaly[:type].to_s)
    when :alert
      broadcast_alert(anomaly)
    when :opportunistic_route
      # Route pending async workloads to surplus zones
      route_to_surplus(anomaly[:zone])
    when :monitor
      Rails.logger.info("[IncidentAgent] Continuing to monitor workload #{workload.id}")
    end
  end

  def self.detect_grid_anomalies
    anomalies = []

    GridDataService::SUPPORTED_ZONES.each do |zone|
      current = GridState.latest_for_zone(zone)
      previous = GridState.for_zone(zone).where("recorded_at < ?", 30.minutes.ago).order(recorded_at: :desc).first
      next unless current && previous

      # Carbon spike
      if previous.carbon_intensity > 0 && current.carbon_intensity > previous.carbon_intensity * (1 + ANOMALY_THRESHOLDS[:carbon_spike_pct] / 100.0)
        anomalies << { type: :carbon_spike, zone: zone, current: current.carbon_intensity, previous: previous.carbon_intensity }
      end

      # Price surge
      if previous.energy_price > 0 && current.energy_price > previous.energy_price * (1 + ANOMALY_THRESHOLDS[:price_surge_pct] / 100.0)
        anomalies << { type: :price_surge, zone: zone, current: current.energy_price, previous: previous.energy_price }
      end

      # Renewable drop
      if previous.renewable_pct > 0 && current.renewable_pct < previous.renewable_pct * (1 - ANOMALY_THRESHOLDS[:renewable_drop_pct] / 100.0)
        anomalies << { type: :renewable_drop, zone: zone, current: current.renewable_pct, previous: previous.renewable_pct }
      end

      # Curtailment opportunity
      if current.curtailment_mw.to_f > ANOMALY_THRESHOLDS[:curtailment_threshold_mw]
        anomalies << { type: :curtailment_opportunity, zone: zone, curtailment_mw: current.curtailment_mw }
      end
    end

    anomalies
  end

  def self.check_surplus_opportunities!
    surplus_zones = GridState.zones_with_surplus
    return if surplus_zones.empty?

    # Find async workloads that could benefit from surplus energy
    async_pending = Workload.needs_routing.where(priority: "async")
    async_pending.each do |workload|
      surplus_nodes = ComputeNode.available.where(grid_zone: surplus_zones)
      next if surplus_nodes.empty?

      Rails.logger.info("[IncidentAgent] Routing async workload #{workload.id} to surplus zone")
      BrokerAgentService.new(workload).route!
    end
  end

  def route_to_surplus(zone)
    Workload.needs_routing.where(priority: "async").limit(5).each do |pending|
      BrokerAgentService.new(pending).route!
    end
  end

  def broadcast_alert(anomaly)
    ActionCable.server.broadcast("dashboard", {
      type: "grid_anomaly",
      anomaly: anomaly,
      workload_id: workload.id,
      timestamp: Time.current.iso8601
    })
  end

  def transition_to!(new_state)
    @state = new_state
    Rails.logger.info("[IncidentAgent] Workload #{workload&.id}: #{new_state}")
  end

  def log_incident(event, data)
    @incidents << {
      event: event,
      data: data,
      state: @state,
      workload_id: workload&.id,
      timestamp: Time.current.iso8601
    }
  end
end
