class Transaction < ApplicationRecord
  belongs_to :workload, optional: true
  belongs_to :organization

  validates :transaction_type, inclusion: { in: %w[charge payout fee refund] }
  validates :amount, numericality: { greater_than: 0 }

  scope :charges, -> { where(transaction_type: "charge") }
  scope :payouts, -> { where(transaction_type: "payout") }
  scope :completed, -> { where(status: "completed") }
  scope :this_month, -> { where("created_at >= ?", Time.current.beginning_of_month) }

  def self.total_revenue
    charges.completed.sum(:amount)
  end

  def self.total_payouts
    payouts.completed.sum(:amount)
  end

  def platform_margin
    return 0 unless transaction_type == "charge"
    amount * 0.15
  end
end
