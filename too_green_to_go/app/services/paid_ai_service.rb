# app/services/paid_ai_service.rb
#
# Integration with Paid.ai
# Tracks exact cost/profitability of every Broker Agent decision.
# Every routing decision, reroute, and completion is logged
# with financial and carbon metrics for ROI analysis.
#
class PaidAiService
  BASE_URL = ENV.fetch("PAID_AI_URL", "https://api.paid.ai/v1")
  API_KEY = ENV.fetch("PAID_AI_KEY", "demo-key")

  class << self
    # Track a routing decision's profitability
    def track_decision(workload:, node:, score:, estimated_cost:, carbon_intensity:, is_reroute: false, platform_fee: 0)
      payload = {
        event: is_reroute ? "workload_rerouted" : "workload_routed",
        workload_id: workload.id,
        workload_type: workload.workload_type,
        node_id: node.id,
        node_region: node.region,
        routing_score: score,
        estimated_cost_eur: estimated_cost,
        carbon_intensity_gco2: carbon_intensity,
        renewable_pct: node.renewable_pct,
        platform_fee_eur: platform_fee,
        green_surplus: node.surplus_energy?,
        reroute_count: workload.reroute_count,
        timestamp: Time.current.iso8601
      }

      log_to_paid_ai("decisions", payload)

      # Store metadata on the workload's latest transaction
      workload.transactions.last&.update(paid_ai_metadata: payload)

      payload
    end

    # Track workload completion profitability
    def track_completion(workload:)
      duration = workload.duration_hours || 0
      cost = workload.actual_cost || 0
      carbon_saved = workload.carbon_saved_grams || 0

      payload = {
        event: "workload_completed",
        workload_id: workload.id,
        duration_hours: duration,
        total_cost_eur: cost,
        platform_fee_eur: cost * 0.15,
        carbon_saved_grams: carbon_saved,
        reroute_count: workload.reroute_count,
        node_region: workload.compute_node&.region,
        green_only: workload.green_only?,
        roi_per_carbon_gram: carbon_saved > 0 ? (cost / carbon_saved).round(4) : 0,
        timestamp: Time.current.iso8601
      }

      log_to_paid_ai("completions", payload)
      payload
    end

    # Get profitability dashboard data
    def profitability_summary
      workloads = Workload.where(status: "completed").includes(:compute_node, :transactions)

      total_revenue = Transaction.charges.completed.sum(:amount)
      total_cost = workloads.sum(:actual_cost)
      total_carbon_saved = workloads.sum(:carbon_saved_grams)
      total_reroutes = workloads.sum(:reroute_count)

      {
        total_workloads: workloads.count,
        total_revenue_eur: total_revenue.to_f.round(2),
        total_platform_fees_eur: (total_revenue * 0.15).to_f.round(2),
        total_carbon_saved_kg: (total_carbon_saved / 1000.0).round(2),
        avg_routing_score: RoutingDecision.average(:score).to_f.round(4),
        reroute_rate: RoutingDecision.reroute_rate,
        total_reroutes: total_reroutes,
        cost_per_kg_carbon_saved: total_carbon_saved > 0 ? (total_cost.to_f / (total_carbon_saved / 1000.0)).round(2) : 0
      }
    end

    private

    def log_to_paid_ai(category, payload)
      if ENV["PAID_AI_KEY"].present? && ENV["PAID_AI_KEY"] != "demo-key"
        begin
          HTTParty.post(
            "#{BASE_URL}/track/#{category}",
            headers: {
              "Authorization" => "Bearer #{API_KEY}",
              "Content-Type" => "application/json"
            },
            body: payload.to_json,
            timeout: 5
          )
        rescue => e
          Rails.logger.warn("[Paid.ai] Failed to log: #{e.message}")
        end
      else
        Rails.logger.info("[Paid.ai] [#{category}] #{payload.to_json}")
      end
    end
  end
end
