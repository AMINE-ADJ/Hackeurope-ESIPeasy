# PricingSnapshot — Dynamic pricing engine records
# Captures the real-time pricing calculation factors for audit trail
class PricingSnapshot < ApplicationRecord
  belongs_to :compute_node, optional: true

  TIERS = %w[recycler_rate surplus_rate green_rate standard_rate].freeze

  validates :pricing_tier, inclusion: { in: TIERS }, allow_nil: true

  scope :current, -> { where("valid_until IS NULL OR valid_until > ?", Time.current) }
  scope :for_zone, ->(zone) { where(grid_zone: zone) }
  scope :for_tier, ->(tier) { where(pricing_tier: tier) }

  def expired?
    valid_until.present? && valid_until <= Time.current
  end

  def effective_rate
    final_rate_eur_per_hour || calculate_rate
  end

  def calculate_rate
    base = base_rate_eur_per_hour || 1.0
    rate = base
    rate *= (1.0 + (green_premium_pct || 0) / 100.0)
    rate *= (1.0 - (surplus_discount_pct || 0) / 100.0)
    rate *= (demand_multiplier || 1.0)
    rate.round(4)
  end

  # Generate a pricing snapshot for a node at the current moment
  def self.snapshot_for_node!(node)
    grid_state = GridState.latest_for_zone(node.grid_zone)
    tier = determine_pricing_tier(node, grid_state)
    factors = calculate_pricing_factors(node, grid_state, tier)

    create!(
      compute_node: node,
      grid_zone: node.grid_zone,
      base_rate_eur_per_hour: factors[:base_rate],
      green_premium_pct: factors[:green_premium],
      surplus_discount_pct: factors[:surplus_discount],
      demand_multiplier: factors[:demand_multiplier],
      final_rate_eur_per_hour: factors[:final_rate],
      pricing_tier: tier,
      factors: factors,
      valid_from: Time.current,
      valid_until: 15.minutes.from_now
    )
  end

  private

  def self.determine_pricing_tier(node, grid_state)
    if node.organization&.always_green? || node.energy_source_type == "waste_heat"
      "recycler_rate"
    elsif grid_state&.surplus_detected?
      "surplus_rate"
    elsif node.green_compliant?
      "green_rate"
    else
      "standard_rate"
    end
  end

  def self.calculate_pricing_factors(node, grid_state, tier)
    base_rates = {
      "H100" => 3.50, "A100" => 2.20, "RTX 4090" => 1.10,
      "RTX 4080" => 0.85, "RTX 3080" => 0.55
    }
    base_rate = base_rates[node.gpu_model] || 1.0

    green_premium = tier == "green_rate" ? 10.0 : 0.0
    surplus_discount = case tier
                       when "recycler_rate" then 40.0
                       when "surplus_rate" then 30.0
                       else 0.0
                       end

    # Demand multiplier based on platform utilization
    busy_nodes = ComputeNode.where(status: "busy").count
    total_nodes = ComputeNode.count
    utilization_ratio = total_nodes > 0 ? busy_nodes.to_f / total_nodes : 0.5
    demand_multiplier = 0.8 + (utilization_ratio * 0.4) # 0.8x to 1.2x

    final_rate = base_rate * (1.0 + green_premium / 100.0) * (1.0 - surplus_discount / 100.0) * demand_multiplier

    {
      base_rate: base_rate.round(4),
      green_premium: green_premium,
      surplus_discount: surplus_discount,
      demand_multiplier: demand_multiplier.round(4),
      final_rate: final_rate.round(4),
      grid_carbon: grid_state&.carbon_intensity,
      grid_price: grid_state&.energy_price,
      node_gpu: node.gpu_model,
      tier: tier
    }
  end
end
