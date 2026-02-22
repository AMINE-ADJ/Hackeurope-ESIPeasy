class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :compute_nodes, dependent: :destroy
  has_many :workloads, dependent: :destroy
  has_many :transactions, dependent: :destroy

  ORG_TYPES = %w[datacenter enterprise gamer energy_recycler ai_consumer].freeze
  PROVIDER_TYPES = %w[datacenter gamer energy_recycler].freeze

  validates :name, presence: true
  validates :org_type, inclusion: { in: ORG_TYPES }
  validates :tier, inclusion: { in: %w[starter pro enterprise] }
  validates :provider_type, inclusion: { in: PROVIDER_TYPES }, allow_nil: true

  scope :datacenters, -> { where(org_type: "datacenter") }
  scope :gamers, -> { where(org_type: "gamer") }
  scope :energy_recyclers, -> { where(org_type: "energy_recycler") }
  scope :ai_consumers, -> { where(org_type: "ai_consumer") }
  scope :providers, -> { where(org_type: PROVIDER_TYPES) }
  scope :active, -> { where(active: true) }
  scope :verified, -> { where(verified: true) }

  # Provider type predicates
  def b2b?
    org_type.in?(%w[datacenter enterprise])
  end

  def b2c?
    org_type == "gamer"
  end

  def energy_recycler?
    org_type == "energy_recycler"
  end

  def ai_consumer?
    org_type == "ai_consumer"
  end

  def provider?
    org_type.in?(PROVIDER_TYPES)
  end

  # Energy Recyclers are always green — bypass grid checks
  def always_green?
    always_green || energy_recycler?
  end

  def onboarding_complete?
    onboarding_completed? && compute_nodes.where(benchmark_completed: true).exists?
  end

  def total_compute_capacity
    compute_nodes.where(status: %w[idle partial]).count
  end

  def available_gpu_slices
    GpuSlice.available.joins(:compute_node).where(compute_nodes: { organization_id: id })
  end

  def revenue_this_month
    transactions.where(transaction_type: "charge")
                .where("created_at >= ?", Time.current.beginning_of_month)
                .sum(:amount)
  end

  def total_carbon_saved
    workloads.where(status: "completed").sum(:carbon_saved_grams)
  end

  # Determine the provider tier for broker routing
  def provider_routing_tier
    if energy_recycler?
      "tier_1_recycler"
    elsif b2b?
      "tier_2_b2b_surplus"
    elsif b2c?
      "tier_3_b2c_green"
    else
      nil
    end
  end
end
