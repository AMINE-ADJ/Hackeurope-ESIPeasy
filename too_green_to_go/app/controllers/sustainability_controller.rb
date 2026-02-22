# Sustainability Dashboard Controller
# Provides impact reporting: carbon savings, green compute metrics, provider leaderboard
class SustainabilityController < ApplicationController
  def dashboard
    completed = Workload.where(status: "completed")

    @impact = {
      total_carbon_saved_kg: compute_total_carbon_saved_kg,
      total_workloads: completed.count,
      avg_carbon_per_workload: completed.count > 0 ? (completed.average(:carbon_saved_grams).to_f / 1000.0).round(2) : 0,
      green_workloads_pct: completed.count > 0 ? (completed.where(green_only: true).count.to_f / completed.count * 100).round(1) : 0,
      recycled_workloads_pct: completed.count > 0 ? (completed.where(green_tier: "100_pct_recycled").count.to_f / completed.count * 100).round(1) : 0,
      total_reroutes: completed.sum(:reroute_count),
      total_migrations: completed.sum(:migration_count),
      avg_renewable_pct: RoutingDecision.average(:renewable_pct_at_decision).to_f.round(1)
    }

    @carbon_by_zone = completed.joins(:compute_node)
                               .group("compute_nodes.grid_zone")
                               .sum(:carbon_saved_grams)
                               .transform_values { |v| (v / 1000.0).round(2) }

    @carbon_by_tier = completed.where.not(broker_tier_used: nil)
                               .group(:broker_tier_used)
                               .sum(:carbon_saved_grams)
                               .transform_values { |v| (v / 1000.0).round(2) }

    @provider_leaderboard = Organization.providers
                                        .joins(:compute_nodes)
                                        .select("organizations.*, SUM(COALESCE(organizations.total_carbon_saved_grams, 0)) as total_saved")
                                        .group("organizations.id")
                                        .order("total_saved DESC")
                                        .limit(10)

    @daily_carbon = completed.where("completed_at >= ?", 30.days.ago)
                             .group_by_day(:completed_at)
                             .sum(:carbon_saved_grams)
                             .transform_values { |v| (v / 1000.0).round(2) }

    @compliance_summary = GreenComplianceEngine.global_compliance_report
  end
end
