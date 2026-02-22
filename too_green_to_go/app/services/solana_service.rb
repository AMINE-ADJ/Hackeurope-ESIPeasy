# app/services/solana_service.rb
#
# Solana integration for B2C gamer payouts and carbon receipt NFTs
# Uses Ed25519 for keypair operations and direct RPC calls
#
class SolanaService
  RPC_URL = ENV.fetch("SOLANA_RPC_URL", "https://api.devnet.solana.com")

  class << self
    # Pay a B2C gamer for providing green compute
    def payout_gamer(compute_node, amount_sol:)
      return mock_payout(compute_node, amount_sol) unless solana_live?

      wallet = compute_node.solana_wallet_address
      raise "No Solana wallet configured" unless wallet.present?

      # In production: build and sign SOL transfer transaction
      # For demo: simulate the payout
      tx_sig = submit_transaction(
        to: wallet,
        amount_lamports: (amount_sol * 1_000_000_000).to_i,
        memo: "TooGreenToGo payout for #{compute_node.name}"
      )

      Transaction.create!(
        organization: compute_node.organization,
        transaction_type: "payout",
        amount: amount_sol,
        currency: "SOL",
        payment_method: "solana",
        solana_tx_signature: tx_sig,
        status: "completed"
      )

      tx_sig
    end

    # Mint a carbon receipt as a Solana compressed NFT
    def mint_carbon_receipt(carbon_receipt)
      return mock_mint(carbon_receipt) unless solana_live?

      metadata = {
        name: "Carbon Receipt ##{carbon_receipt.id}",
        symbol: "TGTG-CR",
        description: "Verified green compute carbon savings: #{carbon_receipt.carbon_saved_grams}g CO2 avoided",
        attributes: [
          { trait_type: "Carbon Saved (g)", value: carbon_receipt.carbon_saved_grams },
          { trait_type: "Renewable %", value: carbon_receipt.renewable_pct_used },
          { trait_type: "Grid Zone", value: carbon_receipt.compute_node.grid_zone },
          { trait_type: "Timestamp", value: carbon_receipt.created_at.iso8601 }
        ]
      }

      # Simplified: in production use Metaplex SDK
      tx_sig = submit_transaction(
        type: "mint_nft",
        metadata: metadata,
        to: carbon_receipt.compute_node.solana_wallet_address
      )

      {
        tx_signature: tx_sig,
        mint_address: "mint_#{SecureRandom.hex(16)}"
      }
    end

    # Verify a carbon receipt on-chain
    def verify_receipt(solana_tx_signature)
      return { verified: true, confirmations: 32 } unless solana_live?

      response = HTTParty.post(RPC_URL, {
        headers: { "Content-Type" => "application/json" },
        body: {
          jsonrpc: "2.0",
          id: 1,
          method: "getTransaction",
          params: [solana_tx_signature, { encoding: "json" }]
        }.to_json
      })

      result = response.parsed_response["result"]
      {
        verified: result.present?,
        confirmations: result&.dig("slot") || 0,
        block_time: result&.dig("blockTime")
      }
    end

    private

    def solana_live?
      ENV["SOLANA_PRIVATE_KEY"].present?
    end

    def submit_transaction(params)
      # Demo mode: return simulated tx signature
      "sim_#{SecureRandom.hex(32)}"
    end

    def mock_payout(compute_node, amount_sol)
      tx_sig = "demo_payout_#{SecureRandom.hex(32)}"

      Transaction.create!(
        organization: compute_node.organization,
        transaction_type: "payout",
        amount: amount_sol,
        currency: "SOL",
        payment_method: "solana",
        solana_tx_signature: tx_sig,
        status: "completed"
      )

      tx_sig
    end

    def mock_mint(carbon_receipt)
      {
        tx_signature: "demo_mint_#{SecureRandom.hex(32)}",
        mint_address: "demo_mint_addr_#{SecureRandom.hex(16)}"
      }
    end
  end
end
