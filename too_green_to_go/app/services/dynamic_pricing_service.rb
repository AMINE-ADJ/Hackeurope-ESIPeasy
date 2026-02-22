# DynamicPricingService — Real-time pricing engine
#
# Calculates GPU compute prices based on:
# - Provider tier (Recycler → B2B Surplus → B2C Green)
# - Grid energy price (surplus discount)
# - Platform demand (supply/demand multiplier)
# - Green premium (for verified green compute)
# - Time of day patterns
class DynamicPricingService
  # Base rates per GPU model (EUR/hour)
  BASE_RATES = {
    "H100" => 3.50, "A100" => 2.20, "RTX 4090" => 1.10,
    "RTX 4080" => 0.85, "RTX 3080" => 0.55, "RTX 3070" => 0.35
  }.freeze

  # Tier discount percentages
  TIER_DISCOUNTS = {
    "recycler_rate" => 40, "surplus_rate" => 30,
    "green_rate" => 10, "standard_rate" => 0
  }.freeze

  class << self
    # Calculate the current price for a compute node
    def price_for(node)
      grid_state = GridState.latest_for_zone(node.grid_zone)
      tier = determine_tier(node, grid_state)
      base = BASE_RATES[node.gpu_model] || 1.0

      # Apply factors
      surplus_discount = grid_state&.surplus_detected? ? 0.30 : 0.0
      green_premium = node.green_compliant? ? 0.10 : 0.0
      demand_mult = demand_multiplier
      time_mult = time_of_day_multiplier

      final = base * (1.0 + green_premium) * (1.0 - surplus_discount) *
              (1.0 - TIER_DISCOUNTS[tier].to_f / 100.0) *
              demand_mult * time_mult

      {
        base_rate: base,
        tier: tier,
        surplus_discount_pct: (surplus_discount * 100).round(1),
        green_premium_pct: (green_premium * 100).round(1),
        demand_multiplier: demand_mult.round(3),
        time_multiplier: time_mult.round(3),
        final_rate: final.round(4),
        currency: "EUR",
        per: "hour"
      }
    end

    # Generate pricing snapshots for all active nodes
    def snapshot_all!
      ComputeNode.available.find_each do |node|
        PricingSnapshot.snapshot_for_node!(node)
      end
    end

    # Calculate cost estimate for a workload
    def estimate_cost(workload, node = nil)
      node ||= workload.compute_node
      return { error: "No node specified" } unless node

      pricing = price_for(node)
      hours = workload.estimated_duration_hours || 1.0
      total = pricing[:final_rate] * hours
      platform_fee = total * 0.15

      {
        hourly_rate: pricing[:final_rate],
        estimated_hours: hours,
        compute_cost: total.round(2),
        platform_fee: platform_fee.round(2),
        total_cost: (total + platform_fee).round(2),
        provider_payout: (total - platform_fee).round(2),
        pricing_tier: pricing[:tier],
        currency: "EUR"
      }
    end

    # Settlement: finalize all pending transactions in a batch
    def settle_batch!
      batch_id = "batch_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
      settled = 0

      Transaction.where(status: "pending").find_each do |tx|
        tx.update!(
          settlement_batch_id: batch_id,
          settled_at: Time.current,
          status: "completed"
        )
        settled += 1
      end

      Rails.logger.info("[Pricing] Settled batch #{batch_id}: #{settled} transactions")
      { batch_id: batch_id, settled_count: settled }
    end

    private

    def determine_tier(node, grid_state)
      if node.always_green?
        "recycler_rate"
      elsif grid_state&.surplus_detected?
        "surplus_rate"
      elsif node.green_compliant?
        "green_rate"
      else
        "standard_rate"
      end
    end

    def demand_multiplier
      busy = ComputeNode.where(status: "busy").count
      total = [ComputeNode.count, 1].max
      ratio = busy.to_f / total
      # 0.8x when idle, 1.3x when very busy
      0.8 + (ratio * 0.5)
    end

    def time_of_day_multiplier
      hour = Time.current.hour
      case hour
      when 0..5   then 0.7   # Night: cheap
      when 6..8   then 0.85  # Morning ramp
      when 9..17  then 1.0   # Business hours
      when 18..21 then 1.15  # Peak evening
      when 22..23 then 0.8   # Night off-peak
      else 1.0
      end
    end
  end
end
