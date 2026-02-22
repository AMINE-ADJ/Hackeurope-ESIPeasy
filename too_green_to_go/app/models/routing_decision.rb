class RoutingDecision < ApplicationRecord
  belongs_to :workload
  belongs_to :compute_node, optional: true

  validates :decision_type, inclusion: { in: %w[initial_route reroute pause resume] }

  scope :reroutes, -> { where(decision_type: "reroute") }
  scope :recent, -> { where("created_at >= ?", 24.hours.ago) }

  def self.reroute_rate
    total = count
    return 0 if total.zero?
    (reroutes.count.to_f / total * 100).round(1)
  end
end
