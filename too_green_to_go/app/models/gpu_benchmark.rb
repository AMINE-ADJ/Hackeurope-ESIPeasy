# GpuBenchmark — Automated hardware verification for provider onboarding
# Runs standardized tests: TFLOPS, memory bandwidth, inference latency, training throughput
# NOTE: Renamed from Benchmark to avoid collision with Ruby's built-in Benchmark module.
class GpuBenchmark < ApplicationRecord
  self.table_name = "benchmarks"

  belongs_to :compute_node

  TYPES = %w[tflops memory_bandwidth inference_latency training_throughput full_suite].freeze
  STATUSES = %w[pending running completed failed].freeze

  validates :benchmark_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :completed, -> { where(status: "completed") }
  scope :for_node, ->(node) { where(compute_node: node) }
  scope :latest, -> { order(completed_at: :desc) }

  def completed?
    status == "completed"
  end

  def passed?
    return false unless completed?
    score.to_f > minimum_threshold
  end

  # Simulate a hardware benchmark (in production, would use actual GPU tooling)
  def run!
    update!(status: "running", started_at: Time.current)

    results = case benchmark_type
              when "tflops"
                run_tflops_benchmark
              when "memory_bandwidth"
                run_memory_benchmark
              when "inference_latency"
                run_inference_benchmark
              when "training_throughput"
                run_training_benchmark
              when "full_suite"
                run_full_suite
              end

    update!(
      status: "completed",
      score: results[:score],
      duration_seconds: results[:duration],
      raw_results: results,
      completed_at: Time.current
    )

    # Update the compute node with benchmark results
    compute_node.update!(
      benchmark_completed: true,
      benchmark_score: results[:score],
      tflops_benchmark: results[:tflops] || compute_node.tflops_benchmark,
      memory_bandwidth_gbps: results[:memory_bandwidth] || compute_node.memory_bandwidth_gbps
    )

    results
  rescue => e
    update!(status: "failed", raw_results: { error: e.message })
    raise
  end

  private

  def minimum_threshold
    case benchmark_type
    when "tflops" then 10.0
    when "memory_bandwidth" then 100.0
    when "inference_latency" then 50.0
    when "training_throughput" then 20.0
    when "full_suite" then 40.0
    else 0.0
    end
  end

  # Simulated benchmarks based on GPU model
  def gpu_base_performance
    case compute_node.gpu_model
    when "H100"     then { tflops: 989, mem_bw: 3350, inf_lat: 5.2, train_tp: 312 }
    when "A100"     then { tflops: 312, mem_bw: 2039, inf_lat: 8.1, train_tp: 156 }
    when "RTX 4090" then { tflops: 165, mem_bw: 1008, inf_lat: 12.3, train_tp: 82 }
    when "RTX 4080" then { tflops: 113, mem_bw: 717, inf_lat: 16.7, train_tp: 56 }
    when "RTX 3080" then { tflops: 89, mem_bw: 760, inf_lat: 18.9, train_tp: 45 }
    else              { tflops: 50, mem_bw: 500, inf_lat: 25.0, train_tp: 25 }
    end
  end

  def add_variance(base, pct = 5)
    variance = base * (pct / 100.0)
    base + rand(-variance..variance)
  end

  def run_tflops_benchmark
    base = gpu_base_performance
    tflops = add_variance(base[:tflops])
    { score: tflops.round(1), tflops: tflops.round(1), duration: rand(10..30).to_f }
  end

  def run_memory_benchmark
    base = gpu_base_performance
    bw = add_variance(base[:mem_bw])
    { score: bw.round(1), memory_bandwidth: bw.round(1), duration: rand(5..15).to_f }
  end

  def run_inference_benchmark
    base = gpu_base_performance
    latency = add_variance(base[:inf_lat])
    # Lower latency = higher score
    { score: (1000.0 / latency).round(1), inference_latency_ms: latency.round(1), duration: rand(15..45).to_f }
  end

  def run_training_benchmark
    base = gpu_base_performance
    tp = add_variance(base[:train_tp])
    { score: tp.round(1), training_throughput_samples_sec: tp.round(1), duration: rand(30..90).to_f }
  end

  def run_full_suite
    tflops = run_tflops_benchmark
    mem = run_memory_benchmark
    inf = run_inference_benchmark
    train = run_training_benchmark
    composite = (tflops[:score] * 0.3 + mem[:score] * 0.1 + inf[:score] * 0.3 + train[:score] * 0.3).round(1)
    {
      score: composite,
      tflops: tflops[:tflops],
      memory_bandwidth: mem[:memory_bandwidth],
      inference_latency_ms: inf[:inference_latency_ms],
      training_throughput_samples_sec: train[:training_throughput_samples_sec],
      duration: tflops[:duration] + mem[:duration] + inf[:duration] + train[:duration]
    }
  end
end
