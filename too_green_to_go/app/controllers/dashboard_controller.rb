class DashboardController < ApplicationController
  def index
    @stats = {
      total_workloads: Workload.count,
      active_workloads: Workload.active.count,
      pending_workloads: Workload.pending.count,
      completed_workloads: Workload.where(status: "completed").count,
      total_nodes: ComputeNode.count,
      green_nodes: ComputeNode.green.count,
      available_nodes: ComputeNode.available.count,
      healthy_nodes: ComputeNode.healthy.count,
      recycler_nodes: ComputeNode.recycler_nodes.count,
      mig_slices_available: GpuSlice.available.count,
      total_carbon_saved_kg: compute_total_carbon_saved_kg,
      total_revenue: Transaction.charges.completed.sum(:amount).to_f.round(2),
      reroute_rate: RoutingDecision.reroute_rate,
      surplus_zones: GridState.zones_with_surplus,
      active_curtailments: CurtailmentEvent.active.count,
      providers_count: Organization.providers.count,
      tier_1_workloads: Workload.where(broker_tier_used: "tier_1_recycler").count,
      tier_2_workloads: Workload.where(broker_tier_used: "tier_2_b2b_surplus").count,
      tier_3_workloads: Workload.where(broker_tier_used: "tier_3_b2c_green").count
    }

    @recent_workloads = Workload.order(created_at: :desc).limit(10).includes(:compute_node, :organization)
    @recent_grid_states = GridState.order(recorded_at: :desc).limit(20)
    @recent_routing = RoutingDecision.order(created_at: :desc).limit(10).includes(:workload, :compute_node)
    @active_curtailments = CurtailmentEvent.active.order(detected_at: :desc).limit(5)
    @grid_zones = GridDataService::SUPPORTED_ZONES.map do |zone|
      state = GridState.latest_for_zone(zone)
      {
        zone: zone,
        carbon_intensity: state&.carbon_intensity || 0,
        renewable_pct: state&.renewable_pct || 0,
        energy_price: state&.energy_price || 0,
        surplus: state&.surplus_detected? || false,
        nodes_count: ComputeNode.where(grid_zone: zone).count,
        trend: state&.carbon_trend || "stable"
      }
    end
  end

  def grid_map
    @grid_zones = GridDataService::SUPPORTED_ZONES.map do |zone|
      state = GridState.latest_for_zone(zone)
      nodes = ComputeNode.where(grid_zone: zone)
      {
        zone: zone,
        carbon_intensity: state&.carbon_intensity&.round(1) || 0,
        renewable_pct: state&.renewable_pct&.round(1) || 0,
        energy_price: state&.energy_price&.round(2) || 0,
        surplus: state&.surplus_detected? || false,
        curtailment_mw: state&.curtailment_mw&.round || 0,
        nodes_total: nodes.count,
        nodes_available: nodes.available.count,
        nodes_green: nodes.green.count,
        dominant_source: state&.dominant_source || "unknown"
      }
    end
  end

  def profitability
    @profitability = PaidAiService.profitability_summary
    @daily_revenue = Transaction.charges.completed
                                .where("created_at >= ?", 30.days.ago)
                                .group_by_day(:created_at)
                                .sum(:amount)
    @carbon_by_zone = Workload.where(status: "completed")
                              .joins(:compute_node)
                              .group("compute_nodes.grid_zone")
                              .sum(:carbon_saved_grams)
  end
end
