# GreenComplianceEngine — Core green gating logic
#
# Implements:
# 1. Grid API Integration: query real-time carbon/renewable data per zone
# 2. B2C Dynamic Gating: gamer nodes only eligible when local grid is >50% renewable
# 3. B2B Surplus Detection: data center nodes eligible during price-surplus windows
# 4. Recycler Priority: Energy Recycler nodes are ALWAYS green, bypass grid checks
# 5. Green Tier enforcement: route requests for "100% recycled" only to Tier 1
class GreenComplianceEngine
  # B2C Green Gate threshold
  B2C_RENEWABLE_THRESHOLD = 50.0 # percent
  # B2B Surplus thresholds
  B2B_PRICE_SURPLUS_THRESHOLD = 30.0 # EUR/MWh (below = surplus window)
  B2B_CURTAILMENT_THRESHOLD = 100.0  # MW of curtailed renewable

  class << self
    # Check if a node passes the green compliance gate
    def compliant?(node, workload = nil)
      # Energy Recyclers always pass
      return true if node.always_green?

      grid_state = GridState.latest_for_zone(node.grid_zone)
      return false unless grid_state

      case node.node_type
      when "energy_recycler"
        true # Always green
      when "datacenter"
        b2b_compliant?(node, grid_state)
      when "gamer"
        b2c_compliant?(node, grid_state)
      else
        false
      end
    end

    # B2C Dynamic Gating: gamer GPU only eligible when local grid > 50% renewable
    def b2c_compliant?(node, grid_state = nil)
      grid_state ||= GridState.latest_for_zone(node.grid_zone)
      return false unless grid_state
      grid_state.renewable_pct.to_f >= B2C_RENEWABLE_THRESHOLD
    end

    # B2B Surplus Detection: datacenter eligible during price/curtailment surplus
    def b2b_compliant?(node, grid_state = nil)
      grid_state ||= GridState.latest_for_zone(node.grid_zone)
      return false unless grid_state

      # B2B nodes are eligible when either:
      # 1. Energy price is in surplus window (cheap)
      # 2. Significant renewable curtailment is happening
      # 3. Grid is green (>50% renewable)
      price_surplus = grid_state.energy_price.to_f < B2B_PRICE_SURPLUS_THRESHOLD
      curtailment_surplus = grid_state.curtailment_mw.to_f > B2B_CURTAILMENT_THRESHOLD
      grid_green = grid_state.renewable_pct.to_f >= B2C_RENEWABLE_THRESHOLD

      price_surplus || curtailment_surplus || grid_green
    end

    # Check compliance for all nodes in a zone
    def zone_compliance(zone)
      grid_state = GridState.latest_for_zone(zone)
      return { zone: zone, status: "no_data" } unless grid_state

      nodes = ComputeNode.in_grid_zone(zone)
      compliant_nodes = nodes.select { |n| compliant?(n) }

      {
        zone: zone,
        renewable_pct: grid_state.renewable_pct,
        energy_price: grid_state.energy_price,
        curtailment_mw: grid_state.curtailment_mw,
        total_nodes: nodes.count,
        compliant_nodes: compliant_nodes.count,
        b2c_gate_open: grid_state.renewable_pct.to_f >= B2C_RENEWABLE_THRESHOLD,
        b2b_surplus_active: grid_state.surplus_detected?,
        green_status: determine_zone_status(grid_state)
      }
    end

    # Full compliance report across all zones (hash keyed by zone)
    def global_compliance_report
      GridDataService::SUPPORTED_ZONES.each_with_object({}) do |zone, report|
        report[zone] = zone_compliance(zone)
      end
    end

    # Filter nodes eligible for a specific workload's green requirements
    def eligible_nodes_for(workload)
      nodes = ComputeNode.available

      # 100% recycled tier: only Energy Recycler nodes
      if workload.requires_recycled_energy?
        return nodes.recycler_nodes
      end

      # Green preferred: filter by compliance
      if workload.requires_green?
        return nodes.select { |n| compliant?(n) }
      end

      # Standard: all available nodes
      nodes.to_a
    end

    # Update green compliance status for all nodes
    def update_all_compliance!
      ComputeNode.find_each do |node|
        is_compliant = compliant?(node)
        node.update!(green_compliant: is_compliant) unless node.green_compliant? == is_compliant
      end
    end

    private

    def determine_zone_status(grid_state)
      if grid_state.renewable_pct.to_f >= 80
        "green"
      elsif grid_state.renewable_pct.to_f >= 50
        "green"
      elsif grid_state.renewable_pct.to_f >= 30
        "mixed"
      else
        "red"
      end
    end
  end
end
