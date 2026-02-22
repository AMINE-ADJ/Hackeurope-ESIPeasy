class ComputeNode < ApplicationRecord
  belongs_to :organization
  has_many :workloads
  has_many :routing_decisions
  has_many :carbon_receipts
  has_many :gpu_slices, dependent: :destroy
  has_many :benchmarks, class_name: "GpuBenchmark", dependent: :destroy
  has_many :health_checks, dependent: :destroy
  has_many :pricing_snapshots, dependent: :destroy

  NODE_TYPES = %w[datacenter gamer energy_recycler].freeze
  COOLING_TYPES = %w[air liquid immersion waste_heat].freeze
  ENERGY_SOURCES = %w[grid solar wind waste_heat nuclear mixed].freeze
  HEALTH_STATUSES = %w[healthy degraded unhealthy unknown].freeze
  PROVIDER_TIERS = %w[recycler b2b_surplus b2c_green].freeze

  validates :name, presence: true
  validates :node_type, inclusion: { in: NODE_TYPES }
  validates :region, presence: true
  validates :gpu_utilization, numericality: { in: 0.0..1.0 }, allow_nil: true

  scope :available, -> { where(status: %w[idle partial]) }
  scope :green, -> { where(green_compliant: true) }
  scope :in_region, ->(region) { where(region: region) }
  scope :in_grid_zone, ->(zone) { where(grid_zone: zone) }
  scope :datacenter_nodes, -> { where(node_type: "datacenter") }
  scope :gamer_nodes, -> { where(node_type: "gamer") }
  scope :recycler_nodes, -> { where(node_type: "energy_recycler") }
  scope :underutilized, -> { where("gpu_utilization <= ?", 0.7) }
  scope :healthy, -> { where(health_status: "healthy") }
  scope :benchmarked, -> { where(benchmark_completed: true) }
  scope :mig_capable, -> { where(mig_enabled: true) }

  # ── Provider Tier (for Smart Broker routing) ──
  def provider_tier
    return "recycler" if energy_recycler_node?
    return "b2b_surplus" if datacenter_node? && surplus_energy?
    return "b2c_green" if gamer_node? && green_compliant?
    "standard"
  end

  def energy_recycler_node?
    node_type == "energy_recycler" || organization&.energy_recycler?
  end

  def datacenter_node?
    node_type == "datacenter"
  end

  def gamer_node?
    node_type == "gamer"
  end

  # Energy Recycler nodes are always green — bypass grid checks
  def always_green?
    energy_recycler_node? || organization&.always_green?
  end

  # ── Composite Green Routing Score (lower = better) ──
  def routing_score(workload = nil)
    carbon_score = (current_carbon_intensity || 500.0) / 500.0
    price_score = (current_energy_price || 100.0) / 200.0
    utilization_penalty = gpu_utilization || 0.0

    weighted = (carbon_score * 0.6) + (price_score * 0.3) + (utilization_penalty * 0.1)

    # Tier bonuses: Energy Recycler > B2B Surplus > B2C Green
    case provider_tier
    when "recycler"     then weighted *= 0.5  # Best: always green
    when "b2b_surplus"  then weighted *= 0.7  # Good: surplus energy
    when "b2c_green"    then weighted *= 0.85 # Decent: green local grid
    end

    # Async workloads get extra bonus on high renewable nodes
    if workload&.priority == "async" && renewable_pct.to_f >= 80.0
      weighted *= 0.8
    end

    weighted.round(4)
  end

  def surplus_energy?
    latest_grid = GridState.where(grid_zone: grid_zone).order(recorded_at: :desc).first
    latest_grid&.surplus_detected? || false
  end

  def available_vram_mb
    return gpu_vram_mb unless gpu_utilization && gpu_vram_mb
    (gpu_vram_mb * (1.0 - gpu_utilization)).round
  end

  def can_handle?(workload)
    return false unless status.in?(%w[idle partial])
    return false if workload.required_vram_mb && available_vram_mb < workload.required_vram_mb
    return false if workload.green_only? && !green_compliant? && !always_green?
    return false if workload.max_carbon_intensity && !always_green? && (current_carbon_intensity || 999) > workload.max_carbon_intensity
    # Budget check
    if workload.budget_max_eur.present? && workload.estimated_duration_hours.present?
      estimated_total = hourly_cost * workload.estimated_duration_hours
      return false if estimated_total > workload.budget_max_eur.to_f
    end
    true
  end

  def hourly_cost
    base = case gpu_model
           when /H100/ then 4.00
           when /A100/ then 2.50
           when /RTX 4090/ then 0.80
           when /RTX 4080/ then 0.65
           when /RTX 3080/ then 0.40
           else 1.00
           end
    # Pricing adjustments by tier
    case provider_tier
    when "recycler"    then base * 0.6  # 40% discount
    when "b2b_surplus" then base * 0.7  # 30% discount
    when "b2c_green"   then base * 0.9  # 10% discount
    else base
    end
  end

  # ── GPU Slicing (MIG) ──
  def sliceable?
    mig_enabled? && gpu_utilization.to_f < 0.7
  end

  def available_slices
    gpu_slices.available
  end

  def create_mig_slices!
    GpuSlice.create_slices_for_node!(self)
  end

  # ── Health & Benchmarking ──
  def run_benchmark!(type = "full_suite")
    benchmark = benchmarks.create!(benchmark_type: type, status: "pending")
    benchmark.run!
    benchmark
  end

  def check_health!
    HealthCheck.check_node!(self)
  end

  def healthy?
    health_status == "healthy"
  end

  def update_grid_status!
    latest = GridState.where(grid_zone: grid_zone).order(recorded_at: :desc).first
    return unless latest

    # Energy recycler nodes are always green regardless of grid
    is_green = always_green? ? true : latest.renewable_pct.to_f >= 50.0

    update!(
      current_carbon_intensity: always_green? ? 0.0 : latest.carbon_intensity,
      current_energy_price: latest.energy_price,
      renewable_pct: always_green? ? 100.0 : latest.renewable_pct,
      green_compliant: is_green,
      provider_tier: provider_tier
    )
  end
end
