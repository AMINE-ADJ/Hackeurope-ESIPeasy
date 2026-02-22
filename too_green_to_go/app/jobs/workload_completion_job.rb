# app/jobs/workload_completion_job.rb
#
# Simulates workload completion for demo purposes.
# In production, this would be triggered by Crusoe API callbacks.
#
class WorkloadCompletionJob < ApplicationJob
  queue_as :default

  def perform(workload_id)
    workload = Workload.find(workload_id)
    return unless workload.status == "running"

    workload.complete!

    # Mint carbon receipt for B2C nodes
    if workload.compute_node&.node_type == "gamer" && workload.carbon_saved_grams.to_f > 0
      receipt = CarbonReceipt.create!(
        workload: workload,
        compute_node: workload.compute_node,
        carbon_saved_grams: workload.carbon_saved_grams,
        renewable_pct_used: workload.compute_node.renewable_pct || 0,
        baseline_carbon_grams: workload.carbon_saved_grams * 2 # simplified baseline
      )
      receipt.mint_on_solana!

      # Pay the gamer
      sol_rate = 0.001 # SOL per gram of carbon saved (demo rate)
      SolanaService.payout_gamer(workload.compute_node, amount_sol: workload.carbon_saved_grams * sol_rate)
    end

    # Charge B2B customer via Stripe
    if workload.organization.b2b?
      workload.transactions.where(status: "pending").find_each do |tx|
        StripeService.charge_for_workload(tx)
      end
    end

    # Track completion in Paid.ai
    PaidAiService.track_completion(workload: workload)

    Rails.logger.info("[WorkloadCompletion] Workload #{workload.id} completed, cost: €#{workload.actual_cost}")
  end
end
