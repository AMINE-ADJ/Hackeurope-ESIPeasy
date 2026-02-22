module Api
  module V1
    class AnalyticsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def profitability
        render json: PaidAiService.profitability_summary
      end

      def carbon_report
        workloads = Workload.where(status: "completed")
        render json: {
          total_carbon_saved_kg: (workloads.sum(:carbon_saved_grams) / 1000.0).round(2),
          total_workloads: workloads.count,
          avg_carbon_per_workload: workloads.count > 0 ? (workloads.average(:carbon_saved_grams).to_f).round(2) : 0,
          by_zone: workloads.joins(:compute_node)
                            .group("compute_nodes.grid_zone")
                            .sum(:carbon_saved_grams)
                            .transform_values { |v| (v / 1000.0).round(2) },
          green_only_pct: workloads.count > 0 ? (workloads.where(green_only: true).count.to_f / workloads.count * 100).round(1) : 0
        }
      end
    end
  end
end
