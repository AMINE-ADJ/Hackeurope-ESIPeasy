# GPU Slice — Virtual partition of an underutilized GPU via MIG
# When a B2B GPU is utilized at <70%, the system creates virtual partitions
# of the remaining capacity to sub-lease to other workloads.
#
# NVIDIA MIG profiles:
#   1g.10gb  → 1/7 of GPU, 10GB VRAM
#   2g.20gb  → 2/7 of GPU, 20GB VRAM
#   3g.40gb  → 3/7 of GPU, 40GB VRAM
#   4g.40gb  → 4/7 of GPU, 40GB VRAM
#   7g.80gb  → Full GPU, 80GB VRAM
class GpuSlice < ApplicationRecord
  belongs_to :compute_node
  belongs_to :workload, optional: true

  MIG_PROFILES = {
    "1g.10gb" => { vram_mb: 10240, compute_fraction: 1.0 / 7 },
    "2g.20gb" => { vram_mb: 20480, compute_fraction: 2.0 / 7 },
    "3g.40gb" => { vram_mb: 40960, compute_fraction: 3.0 / 7 },
    "4g.40gb" => { vram_mb: 40960, compute_fraction: 4.0 / 7 },
    "7g.80gb" => { vram_mb: 81920, compute_fraction: 1.0 }
  }.freeze

  STATUSES = %w[available allocated reserved maintenance].freeze

  validates :slice_id, presence: true, uniqueness: true
  validates :slice_profile, inclusion: { in: MIG_PROFILES.keys }
  validates :vram_mb, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }

  scope :available, -> { where(status: "available") }
  scope :allocated, -> { where(status: "allocated") }
  scope :for_node, ->(node) { where(compute_node: node) }

  def available?
    status == "available"
  end

  def allocated?
    status == "allocated"
  end

  def allocate!(workload)
    update!(
      workload: workload,
      status: "allocated",
      allocated_at: Time.current,
      utilization: 0.0
    )
  end

  def release!
    update!(
      workload: nil,
      status: "available",
      released_at: Time.current,
      utilization: 0.0
    )
  end

  def compute_fraction
    MIG_PROFILES.dig(slice_profile, :compute_fraction) || 0.0
  end

  def hourly_cost
    return hourly_rate if hourly_rate.present?
    base = compute_node.hourly_cost rescue 1.0
    (base * compute_fraction).round(4)
  end

  # Create slices for remaining capacity on an underutilized node
  def self.create_slices_for_node!(node)
    return unless node.mig_enabled?
    return if node.gpu_utilization.to_f >= 0.7 # Only slice if < 70% utilized

    available_fraction = 1.0 - node.gpu_utilization.to_f
    total_vram = node.gpu_vram_mb || 81920

    # Find best MIG profile(s) that fit the available capacity
    slices_created = []
    remaining = available_fraction

    MIG_PROFILES.sort_by { |_, v| -v[:compute_fraction] }.each do |profile, spec|
      while remaining >= spec[:compute_fraction] && spec[:vram_mb] <= total_vram * remaining
        slice = create!(
          compute_node: node,
          slice_id: "#{node.name}-MIG-#{profile}-#{SecureRandom.hex(4)}",
          slice_profile: profile,
          vram_mb: spec[:vram_mb],
          compute_units: spec[:compute_fraction],
          status: "available",
          hourly_rate: (node.hourly_cost * spec[:compute_fraction]).round(4)
        )
        slices_created << slice
        remaining -= spec[:compute_fraction]
        break if remaining < (1.0 / 7) # Can't fit smallest slice
      end
      break if remaining < (1.0 / 7)
    end

    node.update!(
      mig_active_slices: node.gpu_slices.count
    )

    slices_created
  end
end
