# HealthCheck — Continuous monitoring of compute node health
# Detects degradation, thermal throttling, GPU errors and network issues
class HealthCheck < ApplicationRecord
  belongs_to :compute_node

  STATUSES = %w[healthy degraded critical offline].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { where("created_at >= ?", 1.hour.ago) }
  scope :for_node, ->(node) { where(compute_node: node) }
  scope :unhealthy, -> { where(status: %w[degraded critical offline]) }

  after_create :update_node_health!

  def healthy?
    status == "healthy"
  end

  def degraded?
    status == "degraded"
  end

  def critical?
    status == "critical"
  end

  def should_trigger_migration?
    critical? || (degraded? && gpu_errors_detected?)
  end

  # Run a health check on the given node (simulated)
  def self.check_node!(node)
    # In production: query nvidia-smi, network ping, etc.
    metrics = simulate_metrics(node)
    status = evaluate_health(metrics)

    create!(
      compute_node: node,
      gpu_temp_celsius: metrics[:gpu_temp],
      gpu_utilization: metrics[:gpu_util],
      memory_utilization: metrics[:mem_util],
      power_draw_watts: metrics[:power_draw],
      fan_speed_pct: metrics[:fan_speed],
      network_latency_ms: metrics[:net_latency],
      gpu_errors_detected: metrics[:gpu_errors],
      status: status,
      raw_metrics: metrics
    )
  end

  def self.check_all_nodes!
    ComputeNode.where(status: %w[idle busy partial]).find_each do |node|
      check_node!(node)
    end
  end

  private

  def update_node_health!
    compute_node.update!(
      health_status: status,
      last_health_check_at: created_at
    )

    # Trigger migration if node is degraded/critical with active workloads
    if should_trigger_migration?
      compute_node.workloads.where(status: "running").find_each do |workload|
        next unless workload.checkpoint_enabled?
        Rails.logger.warn("[HealthCheck] Node #{compute_node.name} unhealthy — triggering migration for workload #{workload.id}")
        BrokerAgentService.new(workload).reroute!(reason: "node_health_#{status}")
      end
    end
  end

  def self.simulate_metrics(node)
    base_temp = node.status == "busy" ? 72 : 45
    {
      gpu_temp: base_temp + rand(-5..15),
      gpu_util: (node.gpu_utilization.to_f * 100 + rand(-5..5)).clamp(0, 100),
      mem_util: (node.gpu_utilization.to_f * 80 + rand(-10..10)).clamp(0, 100),
      power_draw: node.gpu_model == "H100" ? rand(300..700) : rand(150..350),
      fan_speed: base_temp > 75 ? rand(70..100) : rand(30..60),
      net_latency: rand(1..50).to_f,
      gpu_errors: rand < 0.02 # 2% chance of GPU errors
    }
  end

  def self.evaluate_health(metrics)
    if metrics[:gpu_errors] || metrics[:gpu_temp] > 95
      "critical"
    elsif metrics[:gpu_temp] > 85 || metrics[:net_latency] > 30
      "degraded"
    elsif metrics[:gpu_temp] > 0 && metrics[:net_latency] < 100
      "healthy"
    else
      "offline"
    end
  end
end
