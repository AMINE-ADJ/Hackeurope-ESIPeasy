class Workload < ApplicationRecord
  belongs_to :organization
  belongs_to :compute_node, optional: true
  has_one :gpu_slice, class_name: "GpuSlice", dependent: :nullify
  has_many :routing_decisions, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :carbon_receipts, dependent: :destroy

  TYPES = %w[inference training embedding fine_tune batch_inference].freeze
  STATUSES = %w[pending routing running paused rerouting migrating completed failed].freeze
  PRIORITIES = %w[urgent normal async].freeze
  GREEN_TIERS = %w[standard green_preferred 100_pct_recycled].freeze

  validates :workload_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :green_tier, inclusion: { in: GREEN_TIERS }, allow_nil: true

  scope :active, -> { where(status: %w[routing running paused rerouting migrating]) }
  scope :pending, -> { where(status: "pending") }
  scope :running, -> { where(status: "running") }
  scope :needs_routing, -> { where(status: %w[pending rerouting]) }
  scope :green_only, -> { where(green_only: true) }
  scope :recycled_only, -> { where(green_tier: "100_pct_recycled") }
  scope :async_eligible, -> { where(priority: "async") }
  scope :with_checkpoints, -> { where(checkpoint_enabled: true) }

  after_create_commit -> { broadcast_prepend_to "workloads", partial: "workloads/workload" }
  after_update_commit -> { broadcast_replace_to "workloads", partial: "workloads/workload" }

  # ── State Machine Actions ──

  def route!
    update!(status: "routing")
    BrokerAgentService.new(self).route!
  end

  def pause!(reason: "carbon_spike")
    checkpoint! if checkpoint_enabled?
    update!(status: "paused", paused_at: Time.current)
    routing_decisions.create!(
      decision_type: "pause",
      reason: reason,
      compute_node: compute_node,
      carbon_intensity_at_decision: compute_node&.current_carbon_intensity,
      energy_price_at_decision: compute_node&.current_energy_price
    )
  end

  def reroute!(reason: "carbon_spike")
    update!(status: "rerouting", reroute_count: reroute_count + 1)
    BrokerAgentService.new(self).reroute!(reason: reason)
  end

  def migrate_to!(new_node, reason: "health_degradation")
    checkpoint! if checkpoint_enabled?
    old_node = compute_node
    update!(
      status: "migrating",
      migrated_from_node_id: old_node&.id,
      migration_count: (migration_count || 0) + 1
    )
    # Release old GPU slice if any
    gpu_slice&.release!
    # Assign to new node
    update!(compute_node: new_node, status: "running")
    routing_decisions.create!(
      decision_type: "reroute",
      reason: "live_migration_#{reason}",
      compute_node: new_node,
      carbon_intensity_at_decision: new_node.current_carbon_intensity,
      energy_price_at_decision: new_node.current_energy_price,
      migration_triggered: true,
      broker_tier: new_node.provider_tier
    )
    # Restore from checkpoint on new node
    restore_checkpoint! if checkpoint_enabled? && checkpoint_url.present?
  end

  def complete!
    update!(
      status: "completed",
      completed_at: Time.current,
      carbon_saved_grams: calculate_carbon_savings
    )
    gpu_slice&.release!
    finalize_billing!
  end

  # ── Checkpointing (for Live Migration) ──

  def checkpoint!
    return unless checkpoint_enabled?
    url = "checkpoint://#{id}/#{Time.current.to_i}"
    update!(
      checkpoint_url: url,
      last_checkpoint_at: Time.current
    )
    Rails.logger.info("[Checkpoint] Workload #{id} checkpointed at #{url}")
  end

  def restore_checkpoint!
    return unless checkpoint_url.present?
    Rails.logger.info("[Checkpoint] Workload #{id} restoring from #{checkpoint_url}")
    # In production: would pull checkpoint state from distributed storage
    true
  end

  def needs_checkpoint?
    return false unless checkpoint_enabled? && status == "running"
    return true unless last_checkpoint_at
    last_checkpoint_at < (checkpoint_interval_minutes || 15).minutes.ago
  end

  # ── Green Tier Logic ──

  def requires_recycled_energy?
    green_tier == "100_pct_recycled"
  end

  def requires_green?
    green_only? || green_tier.in?(%w[green_preferred 100_pct_recycled])
  end

  # ── Cost & Duration ──

  def duration_hours
    return nil unless started_at
    end_time = completed_at || Time.current
    ((end_time - started_at) / 3600.0).round(2)
  end

  def estimated_cost
    return 0 unless compute_node
    (compute_node.hourly_cost * (estimated_duration_hours || 1.0)).round(2)
  end

  def within_budget?
    return true unless budget_max_eur.present?
    estimated_cost <= budget_max_eur.to_f
  end

  # ── Live Carbon Estimation (for running workloads, not yet completed) ──
  def estimated_carbon_saved_grams
    return carbon_saved_grams if status == "completed" && carbon_saved_grams.to_f > 0
    return 0 unless compute_node

    baseline = 400.0
    actual = compute_node.always_green? ? 0.0 : (compute_node.current_carbon_intensity || 250.0)
    gpu_kw = case compute_node.gpu_model
             when /H100/ then 0.70; when /A100/ then 0.40
             when /RTX 4090/ then 0.35; when /RTX 4080/ then 0.32
             else 0.30
             end
    hours = if started_at
              [(Time.current - started_at) / 3600.0, 0.25].max
            else
              estimated_duration_hours || 1.0
            end
    pue = compute_node.pue_ratio || 1.2
    ((baseline - actual) * gpu_kw * hours * pue).round(2)
  end

  # ── Broker Tier Display ──

  def broker_tier_label
    case broker_tier_used
    when "tier_1_recycler"    then "Tier 1 — Energy Recycler"
    when "tier_2_b2b_surplus" then "Tier 2 — B2B Surplus"
    when "tier_3_b2c_green"   then "Tier 3 — B2C Green"
    else "Unassigned"
    end
  end

  private

  def calculate_carbon_savings
    return 0 unless compute_node

    # Baseline: what this workload WOULD have consumed on a dirty grid (EU avg ~400 gCO2/kWh)
    baseline_intensity = 400.0

    # Actual: the node's real-time carbon intensity (0 for always-green recyclers)
    actual_intensity = compute_node.always_green? ? 0.0 : (compute_node.current_carbon_intensity || 250.0)

    # GPU power draw: scale by GPU model (kW average during compute)
    gpu_kw = case compute_node.gpu_model
             when /H100/     then 0.70
             when /A100/     then 0.40
             when /RTX 4090/ then 0.35
             when /RTX 4080/ then 0.32
             when /RTX 3080/ then 0.30
             else 0.30
             end

    # Duration: use actual or estimated, minimum 0.25h (15 min) for short demo jobs
    hours = [duration_hours || estimated_duration_hours || 1.0, 0.25].max

    # PUE (Power Usage Effectiveness): accounts for cooling overhead
    pue = compute_node.pue_ratio || 1.2

    # Total energy = GPU power * time * PUE
    total_kwh = gpu_kw * hours * pue

    # Carbon saved = (baseline - actual) * energy consumed
    ((baseline_intensity - actual_intensity) * total_kwh).round(2)
  end

  def finalize_billing!
    cost = (compute_node&.hourly_cost || 1.0) * (duration_hours || 1.0)
    platform_fee = cost * 0.15
    provider_payout = cost * 0.85

    # Create charge transaction
    transactions.create!(
      organization: organization,
      transaction_type: "charge",
      amount: cost + platform_fee,
      currency: "EUR",
      payment_method: organization.b2b? ? "stripe" : "solana",
      platform_fee_amount: platform_fee,
      provider_payout_amount: provider_payout,
      status: "pending"
    )

    # Create provider payout transaction
    if compute_node&.organization
      Transaction.create!(
        workload: self,
        organization: compute_node.organization,
        transaction_type: "payout",
        amount: provider_payout,
        currency: "EUR",
        payment_method: compute_node.gamer_node? ? "solana" : "stripe",
        status: "pending"
      )
    end
  end
end
