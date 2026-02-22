# app/services/broker_agent_service.rb
#
# The CORE of Too Green To Go: Smart Broker with Tiered Priority Matching
#
# Routing Tiers (evaluated in order):
#   Tier 1 — Energy Recyclers: Always-green nodes powered by waste heat / renewables
#   Tier 2 — B2B Data Centers: Nodes in "price surplus" / curtailment windows
#   Tier 3 — B2C Gamers: Consumer GPUs with green local grids (>50% renewable)
#
# The broker:
# 1. Receives a workload submission (Docker image + VRAM + budget + green tier)
# 2. Evaluates candidates through the Green Compliance Engine
# 3. Routes through the tiered priority system
# 4. Supports GPU slice allocation for partial-capacity matching
# 5. Triggers live migration if conditions degrade
# 6. Logs every decision for audit trail & profitability
#
class BrokerAgentService
  CARBON_WEIGHT = 0.6
  PRICE_WEIGHT = 0.3
  UTILIZATION_WEIGHT = 0.1
  REROUTE_THRESHOLD = 0.25
  MAX_REROUTES = 5

  # Tier ordering: lower = higher priority
  TIER_PRIORITY = {
    "tier_1_recycler" => 1,
    "tier_2_b2b_surplus" => 2,
    "tier_3_b2c_green" => 3
  }.freeze

  attr_reader :workload, :decision_log

  def initialize(workload)
    @workload = workload
    @decision_log = []
  end

  # ============================================================
  # PRIMARY ROUTING — Tiered Priority Matching
  # ============================================================
  def route!
    log_step("ROUTE_START", "Beginning tiered routing for workload #{workload.id} (#{workload.workload_type}, green_tier: #{workload.green_tier})")

    # Step 1: Get green-compliant candidates from the compliance engine
    all_candidates = GreenComplianceEngine.eligible_nodes_for(workload)
    all_candidates = all_candidates.select { |n| n.can_handle?(workload) }

    if all_candidates.empty?
      # Try GPU slices as fallback
      slice = try_slice_routing!
      return slice if slice

      log_step("NO_CANDIDATES", "No eligible compute nodes or GPU slices found")
      workload.update!(status: "pending")
      return { success: false, reason: "no_candidates" }
    end

    # Step 2: Categorize candidates by tier
    tiered = categorize_by_tier(all_candidates)
    log_step("TIER_ANALYSIS", "Tier 1: #{tiered[:tier_1].size}, Tier 2: #{tiered[:tier_2].size}, Tier 3: #{tiered[:tier_3].size}")

    # Step 3: Route through tiers in priority order
    best = route_through_tiers!(tiered)

    if best.nil?
      log_step("NO_CANDIDATES", "No suitable node found across all tiers")
      workload.update!(status: "pending")
      return { success: false, reason: "no_candidates" }
    end

    log_step("ROUTE_DECISION", "Selected #{best[:node].name} [#{best[:tier]}] (score: #{best[:score]}, carbon: #{best[:carbon]}g, price: €#{best[:price]}/h)")

    assign_to_node!(best[:node], decision_type: "initial_route", tier: best[:tier], tiered: tiered)
    track_profitability!(best)

    { success: true, node: best[:node], score: best[:score], tier: best[:tier] }
  end

  # ============================================================
  # ADAPTIVE REROUTING
  # ============================================================
  def reroute!(reason: "carbon_spike")
    return { success: false, reason: "max_reroutes" } if workload.reroute_count >= MAX_REROUTES

    log_step("REROUTE_START", "Rerouting due to: #{reason}")

    old_node = workload.compute_node

    # Checkpoint before pausing if enabled
    if workload.checkpoint_enabled? && workload.status == "running"
      CheckpointService.checkpoint!(workload)
    end

    workload.pause!(reason: reason) if workload.status == "running"

    all_candidates = GreenComplianceEngine.eligible_nodes_for(workload)
    all_candidates = all_candidates.select { |n| n.can_handle?(workload) }
    all_candidates.reject! { |n| n.id == old_node&.id }

    if all_candidates.empty?
      log_step("REROUTE_FAILED", "No better nodes available, resuming on current node")
      workload.update!(status: "running")
      return { success: false, reason: "no_alternatives" }
    end

    tiered = categorize_by_tier(all_candidates)
    best = route_through_tiers!(tiered)

    unless best
      workload.update!(status: "running")
      return { success: false, reason: "no_suitable_alternative" }
    end

    old_score = old_node&.routing_score(workload) || 1.0
    improvement = ((old_score - best[:score]) / [old_score, 0.001].max).round(4)

    if improvement < REROUTE_THRESHOLD
      log_step("REROUTE_SKIPPED", "Best alternative only #{(improvement * 100).round(1)}% better")
      workload.update!(status: "running")
      return { success: false, reason: "improvement_insufficient" }
    end

    log_step("REROUTE_DECISION", "Rerouting: #{old_node&.name} → #{best[:node].name} (#{(improvement * 100).round(1)}% improvement)")

    # Use live migration if checkpoint is enabled
    if workload.checkpoint_enabled?
      CheckpointService.live_migrate!(workload, best[:node], reason: reason)
    else
      assign_to_node!(best[:node], decision_type: "reroute", reason: reason, old_node: old_node, tier: best[:tier], tiered: tiered)
    end

    track_profitability!(best, reroute: true)
    { success: true, node: best[:node], improvement: improvement, tier: best[:tier] }
  end

  # ============================================================
  # CONTINUOUS MONITORING
  # ============================================================
  def self.check_all_running_workloads!
    Workload.running.includes(:compute_node).find_each do |workload|
      node = workload.compute_node
      next unless node

      node.update_grid_status!

      # Check for health-based migration
      if node.health_status.in?(%w[degraded critical]) && workload.checkpoint_enabled?
        new(workload).reroute!(reason: "node_health_#{node.health_status}")
        next
      end

      if should_reroute?(workload, node)
        reason = detect_reroute_reason(node)
        new(workload).reroute!(reason: reason)
      end
    end

    # Auto-manage GPU slices
    GpuSlicingService.auto_manage!

    # Checkpoint workloads that are due
    CheckpointService.checkpoint_all_due!
  end

  # ============================================================
  # ASYNC SURPLUS ROUTING — On surplus event, route queued async workloads
  # ============================================================
  def self.route_async_on_surplus!(zone)
    surplus_nodes = ComputeNode.available.in_grid_zone(zone)
    return if surplus_nodes.empty?

    Workload.needs_routing.where(priority: "async").find_each do |workload|
      result = new(workload).route!
      if result[:success]
        Rails.logger.info("[Broker] Surplus-routed async workload #{workload.id} to #{result[:node].name} in #{zone}")
      end
    end
  end

  private

  # ── Tier Categorization ──

  def categorize_by_tier(candidates)
    tier_1 = [] # Energy Recyclers (always green)
    tier_2 = [] # B2B Data Centers in surplus window
    tier_3 = [] # B2C Gamers with green local grid

    candidates.each do |node|
      if node.energy_recycler_node? || node.always_green?
        tier_1 << node
      elsif node.datacenter_node? && node.surplus_energy?
        tier_2 << node
      elsif node.gamer_node? && node.green_compliant?
        tier_3 << node
      elsif node.datacenter_node? && node.green_compliant?
        tier_2 << node # B2B green but not in surplus → still Tier 2
      else
        tier_3 << node # Fallback to Tier 3
      end
    end

    { tier_1: tier_1, tier_2: tier_2, tier_3: tier_3 }
  end

  def route_through_tiers!(tiered)
    # For 100% recycled workloads: only Tier 1
    if workload.requires_recycled_energy?
      return score_and_pick(tiered[:tier_1], "tier_1_recycler")
    end

    # Try tiers in order
    if tiered[:tier_1].any?
      result = score_and_pick(tiered[:tier_1], "tier_1_recycler")
      return result if result
    end

    if tiered[:tier_2].any?
      result = score_and_pick(tiered[:tier_2], "tier_2_b2b_surplus")
      return result if result
    end

    if tiered[:tier_3].any?
      result = score_and_pick(tiered[:tier_3], "tier_3_b2c_green")
      return result if result
    end

    nil
  end

  def score_and_pick(candidates, tier_label)
    return nil if candidates.empty?

    scored = score_candidates(candidates)
    best = scored.first
    return nil unless best

    best[:tier] = tier_label
    best
  end

  # ── GPU Slice Fallback ──

  def try_slice_routing!
    return nil unless workload.required_vram_mb

    slice = GpuSlicingService.find_slice_for(workload)
    return nil unless slice

    log_step("SLICE_ROUTE", "Routing to GPU slice #{slice.slice_id} on #{slice.compute_node.name}")
    GpuSlicingService.allocate_slice!(slice, workload)

    node = slice.compute_node
    workload.update!(
      compute_node: node,
      status: "running",
      started_at: Time.current,
      assigned_gpu_slice_id: slice.id,
      broker_tier_used: node.provider_tier == "recycler" ? "tier_1_recycler" : "tier_2_b2b_surplus"
    )

    { success: true, node: node, score: node.routing_score(workload), tier: "gpu_slice", slice: slice }
  end

  # ── Scoring ──

  def score_candidates(candidates)
    candidates.map do |node|
      carbon = node.always_green? ? 0.0 : (node.current_carbon_intensity || 500.0)
      price = node.current_energy_price || 100.0
      util = node.gpu_utilization || 0.0

      carbon_score = carbon / 500.0
      price_score = price / 200.0
      util_score = util

      composite = (carbon_score * CARBON_WEIGHT) +
                  (price_score * PRICE_WEIGHT) +
                  (util_score * UTILIZATION_WEIGHT)

      # Tier-based scoring bonuses
      case node.provider_tier
      when "recycler"    then composite *= 0.5
      when "b2b_surplus" then composite *= 0.7
      when "b2c_green"   then composite *= 0.85
      end

      # Async workloads prefer high-renewable nodes
      if workload.priority == "async" && node.renewable_pct.to_f >= 80.0
        composite *= 0.8
      end

      # Health bonus for healthy nodes
      composite *= 0.95 if node.healthy?
      composite *= 1.2 if node.health_status == "degraded"

      pricing = DynamicPricingService.price_for(node)

      {
        node: node,
        score: composite.round(4),
        carbon: carbon.round(1),
        price: pricing[:final_rate].round(2),
        renewable_pct: node.renewable_pct.to_f.round(1),
        surplus: node.surplus_energy?,
        provider_tier: node.provider_tier
      }
    end.sort_by { |c| c[:score] }
  end

  # ── Assignment ──

  def assign_to_node!(node, decision_type:, reason: nil, old_node: nil, tier: nil, tiered: nil)
    tier_used = tier || determine_tier_label(node)

    workload.update!(
      compute_node: node,
      status: "running",
      started_at: workload.started_at || Time.current,
      broker_tier_used: tier_used
    )

    RoutingDecision.create!(
      workload: workload,
      compute_node: node,
      decision_type: decision_type,
      reason: reason,
      carbon_intensity_at_decision: node.current_carbon_intensity,
      energy_price_at_decision: node.current_energy_price,
      renewable_pct_at_decision: node.renewable_pct,
      score: node.routing_score(workload),
      broker_tier: tier_used,
      candidates_per_tier: tiered ? {
        tier_1: tiered[:tier_1].size,
        tier_2: tiered[:tier_2].size,
        tier_3: tiered[:tier_3].size
      }.to_json : nil,
      alternatives_considered: @decision_log.last(5).to_json,
      agent_reasoning: {
        workload_type: workload.workload_type,
        priority: workload.priority,
        green_tier: workload.green_tier,
        green_only: workload.green_only?,
        reroute_count: workload.reroute_count,
        broker_tier: tier_used,
        old_node: old_node&.name,
        new_node: node.name,
        checkpoint_enabled: workload.checkpoint_enabled?,
        timestamp: Time.current.iso8601
      }.to_json
    )

    node.update!(status: "busy", gpu_utilization: [node.gpu_utilization + 0.3, 1.0].min)

    if old_node && old_node != node
      old_node.update!(status: "idle", gpu_utilization: [old_node.gpu_utilization - 0.3, 0.0].max)
    end
  end

  def determine_tier_label(node)
    if node.energy_recycler_node? || node.always_green?
      "tier_1_recycler"
    elsif node.datacenter_node?
      "tier_2_b2b_surplus"
    else
      "tier_3_b2c_green"
    end
  end

  # ── Profitability Tracking ──

  def track_profitability!(scored_node, reroute: false)
    PaidAiService.track_decision(
      workload: workload,
      node: scored_node[:node],
      score: scored_node[:score],
      estimated_cost: workload.estimated_cost,
      carbon_intensity: scored_node[:carbon],
      is_reroute: reroute,
      platform_fee: workload.estimated_cost * 0.15
    )
  end

  # ── Reroute Detection ──

  def self.should_reroute?(workload, node)
    return false if workload.reroute_count >= MAX_REROUTES

    last_decision = workload.routing_decisions.order(created_at: :desc).first
    return false unless last_decision

    original_carbon = last_decision.carbon_intensity_at_decision || 0
    current_carbon = node.current_carbon_intensity || 0

    carbon_spike = original_carbon > 0 && current_carbon > original_carbon * 1.5
    green_lost = workload.requires_green? && !node.green_compliant? && !node.always_green?
    original_price = last_decision.energy_price_at_decision || 0
    price_surge = original_price > 0 && (node.current_energy_price || 0) > original_price * 2.0
    budget_exceeded = workload.budget_max_eur.present? && !workload.within_budget?

    carbon_spike || green_lost || price_surge || budget_exceeded
  end

  def self.detect_reroute_reason(node)
    if node.current_carbon_intensity.to_f > 300
      "carbon_spike"
    elsif !node.green_compliant? && !node.always_green?
      "green_compliance_lost"
    else
      "price_surge"
    end
  end

  def log_step(event, message)
    entry = { event: event, message: message, timestamp: Time.current.iso8601 }
    @decision_log << entry
    Rails.logger.info("[BrokerAgent] #{event}: #{message}")
  end
end
