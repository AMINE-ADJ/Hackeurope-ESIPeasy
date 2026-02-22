# Admin Controller — "Crusoe Override" manual dashboard + Global controls
# Provides:
# 1. Crusoe Override: manually assign/reassign workloads to nodes
# 2. Global heatmap data: carbon intensity, node status per zone
# 3. Settlement management: batch settle pending transactions
# 4. Platform analytics: provider stats, compliance overview
class AdminController < ApplicationController
  def dashboard
    @stats = {
      total_providers: Organization.providers.count,
      verified_providers: Organization.providers.verified.count,
      total_nodes: ComputeNode.count,
      healthy_nodes: ComputeNode.healthy.count,
      mig_nodes: ComputeNode.mig_capable.count,
      total_slices: GpuSlice.count,
      available_slices: GpuSlice.available.count,
      active_workloads: Workload.active.count,
      pending_workloads: Workload.pending.count,
      total_revenue: Transaction.charges.completed.sum(:amount).to_f.round(2),
      pending_settlements: Transaction.where(status: "pending").count,
      total_carbon_saved_kg: compute_total_carbon_saved_kg,
      active_curtailments: CurtailmentEvent.active.count
    }

    @providers_by_type = Organization.providers.group(:org_type).count
    @workloads_by_tier = Workload.where.not(broker_tier_used: nil).group(:broker_tier_used).count
    @recent_decisions = RoutingDecision.order(created_at: :desc).limit(20).includes(:workload, :compute_node)
    @compliance_report = GreenComplianceEngine.global_compliance_report
  end

  # Crusoe Override: manually assign a workload to a specific node
  def override_routing
    workload = Workload.find(params[:workload_id])
    node = ComputeNode.find(params[:node_id])

    # Checkpoint before override if enabled
    CheckpointService.checkpoint!(workload) if workload.checkpoint_enabled? && workload.status == "running"

    old_node = workload.compute_node
    workload.update!(
      compute_node: node,
      status: "running",
      started_at: workload.started_at || Time.current,
      broker_tier_used: "admin_override"
    )

    RoutingDecision.create!(
      workload: workload,
      compute_node: node,
      decision_type: "reroute",
      reason: "admin_crusoe_override",
      carbon_intensity_at_decision: node.current_carbon_intensity,
      energy_price_at_decision: node.current_energy_price,
      renewable_pct_at_decision: node.renewable_pct,
      score: node.routing_score(workload),
      broker_tier: "admin_override"
    )

    if old_node && old_node != node
      old_node.update!(status: "idle", gpu_utilization: [old_node.gpu_utilization - 0.3, 0.0].max)
    end
    node.update!(status: "busy", gpu_utilization: [node.gpu_utilization + 0.3, 1.0].min)

    redirect_to admin_dashboard_path, notice: "Override: #{workload.name} → #{node.name}"
  end

  # Global Heatmap data (JSON for frontend)
  def heatmap_data
    zones = GridDataService::SUPPORTED_ZONES.map do |zone|
      state = GridState.latest_for_zone(zone)
      nodes = ComputeNode.where(grid_zone: zone)
      compliance = GreenComplianceEngine.zone_compliance(zone)

      {
        zone: zone,
        carbon_intensity: state&.carbon_intensity&.round(1) || 0,
        renewable_pct: state&.renewable_pct&.round(1) || 0,
        energy_price: state&.energy_price&.round(2) || 0,
        surplus: state&.surplus_detected? || false,
        curtailment_mw: state&.curtailment_mw&.round || 0,
        nodes_total: nodes.count,
        nodes_available: nodes.available.count,
        nodes_healthy: nodes.healthy.count,
        recycler_nodes: nodes.recycler_nodes.count,
        b2c_gate_open: compliance[:b2c_gate_open],
        green_status: compliance[:green_status],
        active_workloads: Workload.running.joins(:compute_node).where(compute_nodes: { grid_zone: zone }).count
      }
    end

    respond_to do |format|
      format.html { @zones = zones }
      format.json { render json: zones }
    end
  end

  # Batch settle pending transactions
  def settle
    result = DynamicPricingService.settle_batch!
    redirect_to admin_dashboard_path, notice: "Settled #{result[:settled_count]} transactions (batch: #{result[:batch_id]})"
  end

  # Node health overview
  def health_overview
    @nodes = ComputeNode.includes(:health_checks).order(:health_status, :name)
    @recent_checks = HealthCheck.order(created_at: :desc).limit(50).includes(:compute_node)
  end

  # GPU Slicing management
  def gpu_slices
    @slices = GpuSlice.includes(:compute_node, :workload).order(created_at: :desc)
    @nodes_with_slices = ComputeNode.mig_capable.includes(:gpu_slices)
  end

  # Trigger GPU slice auto-management
  def manage_slices
    result = GpuSlicingService.auto_manage!
    redirect_to admin_gpu_slices_path, notice: "Slicing: #{result[:sliced]} created, #{result[:reclaimed]} reclaimed"
  end
end
