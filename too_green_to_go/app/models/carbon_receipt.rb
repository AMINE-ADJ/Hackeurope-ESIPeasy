class CarbonReceipt < ApplicationRecord
  belongs_to :workload
  belongs_to :compute_node

  validates :carbon_saved_grams, numericality: true
  validates :status, inclusion: { in: %w[pending minted verified] }

  scope :minted, -> { where(status: "minted") }
  scope :verified, -> { where(status: "verified") }

  def self.total_carbon_saved
    sum(:carbon_saved_grams)
  end

  def mint_on_solana!
    result = SolanaService.mint_carbon_receipt(self)
    update!(
      solana_tx_signature: result[:tx_signature],
      solana_mint_address: result[:mint_address],
      status: "minted"
    )
  end
end
