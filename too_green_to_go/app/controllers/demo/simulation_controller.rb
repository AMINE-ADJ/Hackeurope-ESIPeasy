module Demo
  class SimulationController < ApplicationController
    # Simulate a full grid data ingestion cycle with all new services
    def grid_cycle
      GridDataService.ingest_all_zones!
      IncidentAgentService.monitor_and_adapt!
      redirect_to dashboard_path, notice: "Full cycle: grid ingested, health checked, slices managed, compliance updated."
    end

    # Create a demo workload with tiered routing
    def create_workload
      org = Organization.where(org_type: %w[enterprise ai_consumer]).first || Organization.first
      green_tier = %w[standard green_preferred 100_pct_recycled].sample
      workload = Workload.create!(
        organization: org,
        name: "Demo #{%w[Inference Training Embedding Batch].sample} Job #{rand(1000)}",
        workload_type: %w[inference training embedding fine_tune batch_inference].sample,
        priority: %w[urgent normal async].sample,
        required_vram_mb: [8192, 16384, 24576, 40960, 81920].sample,
        green_only: green_tier != "standard",
        green_tier: green_tier,
        max_carbon_intensity: green_tier == "standard" ? nil : [100, 200, 300].sample,
        estimated_duration_hours: rand(0.5..8.0).round(1),
        docker_image: "ghcr.io/demo/#{%w[llama mistral bert gpt].sample}:latest",
        budget_max_eur: rand(5..100).to_f.round(2),
        checkpoint_enabled: [true, false].sample,
        checkpoint_interval_minutes: [5, 10, 15, 30].sample,
        status: "pending"
      )

      result = BrokerAgentService.new(workload).route!
      if result[:success]
        tier_label = result[:tier] || "unknown"
        msg = "Routed to #{result[:node].name} via #{tier_label}"
      else
        msg = "No candidates available"
      end
      redirect_to workload_path(workload), notice: "Demo workload created. #{msg}"
    end

    # Force a reroute on a random running workload
    def trigger_reroute
      workload = Workload.running.order("RANDOM()").first
      if workload
        result = BrokerAgentService.new(workload).reroute!(reason: "demo_carbon_spike")
        redirect_to workload_path(workload), notice: "Reroute triggered: #{result[:success] ? 'success' : result[:reason]}"
      else
        redirect_to dashboard_path, alert: "No running workloads to reroute."
      end
    end

    # Force a curtailment event with ElevenLabs alert
    def trigger_curtailment
      zone = GridDataService::SUPPORTED_ZONES.sample
      event = CurtailmentEvent.create!(
        grid_zone: zone,
        curtailment_mw: rand(300..2000),
        potential_savings_eur: rand(50..500).to_f,
        potential_carbon_savings_g: rand(10000..100000),
        severity: %w[medium high critical].sample,
        alert_message: "DEMO: Massive renewable curtailment in #{zone}!",
        detected_at: Time.current,
        expires_at: 2.hours.from_now
      )
      event.trigger_alert!
      redirect_to curtailment_event_path(event), notice: "Curtailment event created with audio alert."
    end

    # Complete all running workloads (synchronous for demo — no Sidekiq needed)
    def complete_workloads
      completed = 0
      total_carbon = 0.0
      Workload.running.find_each do |w|
        w.complete!
        total_carbon += w.carbon_saved_grams.to_f
        completed += 1
      end
      # Also update org-level carbon tracking
      Organization.providers.find_each do |org|
        saved = org.compute_nodes.joins(:workloads)
                   .where(workloads: { status: "completed" })
                   .sum("workloads.carbon_saved_grams")
        org.update_columns(total_carbon_saved_grams: saved)
      end
      redirect_to dashboard_path, notice: "#{completed} workloads completed. #{(total_carbon / 1000.0).round(2)} kg CO₂ saved!"
    end

    # Demo: trigger health check and migration
    def trigger_health_migration
      # Degrade a random node and trigger migration
      node = ComputeNode.where(status: "busy").order("RANDOM()").first
      if node
        node.update!(health_status: "critical")
        migrations = CheckpointService.check_and_migrate!
        redirect_to dashboard_path, notice: "Health triggered: #{node.name} marked critical, #{migrations} migrations."
      else
        redirect_to dashboard_path, alert: "No busy nodes to degrade."
      end
    end

    # Demo: auto-manage GPU slices
    def trigger_slicing
      result = GpuSlicingService.auto_manage!
      redirect_to dashboard_path, notice: "GPU Slicing: #{result[:sliced]} created, #{result[:reclaimed]} reclaimed."
    end
  end
end
