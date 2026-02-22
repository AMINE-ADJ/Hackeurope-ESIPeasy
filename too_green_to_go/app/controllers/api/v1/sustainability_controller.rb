module Api
  module V1
    class SustainabilityController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/sustainability
      def index
        render json: {
          stats: build_stats,
          pricing_history: build_pricing_history,
          transactions: build_transactions
        }
      end

      private

      def build_stats
        completed = Workload.where(status: "completed")
        running = Workload.running

        completed_grams = completed.sum(:carbon_saved_grams)
        running_grams = running.includes(:compute_node).sum { |w| w.estimated_carbon_saved_grams }
        total_co2_kg = ((completed_grams + running_grams) / 1000.0).round(2)

        total_revenue = Transaction.charges.completed.sum(:amount).to_f
        total_payouts = Transaction.payouts.completed.sum(:amount).to_f
        energy_recovered = (total_co2_kg * 0.072).round(1) # ~72 Wh per gram CO2 avoided

        {
          co2Saved: "#{total_co2_kg > 1000 ? "#{(total_co2_kg / 1000.0).round(1)}K" : total_co2_kg}",
          revenue: total_revenue.round(2),
          savings: (total_revenue * 0.43).round(2), # 43% avg savings
          energyRecovered: "#{energy_recovered} MWh",
          wallet: (total_revenue - total_payouts).round(2),
          carbonReceipts: CarbonReceipt.count,
          mintedReceipts: CarbonReceipt.minted.count
        }
      end

      def build_pricing_history
        # Generate 30-day pricing history from snapshots or simulate
        (0..29).map do |i|
          day = (29 - i).days.ago
          day_label = day.strftime("%b %d")

          snapshots = PricingSnapshot.where(created_at: day.beginning_of_day..day.end_of_day)

          if snapshots.any?
            recycled = snapshots.where(pricing_tier: "recycler_rate").average(:final_rate_eur_per_hour)&.to_f || 0
            standard = snapshots.where(pricing_tier: %w[standard_rate green_rate]).average(:final_rate_eur_per_hour)&.to_f || 0
            gamer = snapshots.where(pricing_tier: "surplus_rate").average(:final_rate_eur_per_hour)&.to_f || 0

            {
              day: day_label,
              standard: [standard, 0.5].max.round(2),
              recycled: [recycled, 0.3].max.round(2),
              gamer: [gamer, 0.1].max.round(2)
            }
          else
            # Simulate with slight daily variation
            seed = day.yday + day.year * 365
            r = Random.new(seed)
            {
              day: day_label,
              standard: (0.8 + r.rand * 0.4).round(2),
              recycled: (1.0 + r.rand * 0.5).round(2),
              gamer: (0.2 + r.rand * 0.3).round(2)
            }
          end
        end
      end

      def build_transactions
        Transaction.order(created_at: :desc).limit(20).includes(:workload).map do |tx|
          type_label = case tx.transaction_type
                       when "charge" then "Earning"
                       when "payout" then "Payout"
                       when "fee" then "Fee"
                       when "refund" then "Refund"
                       else tx.transaction_type.capitalize
                       end

          amount_str = case tx.transaction_type
                       when "charge" then "+€#{tx.amount.to_f.round(2)}"
                       when "payout" then "-€#{tx.amount.to_f.round(2)}"
                       when "fee" then "-€#{tx.amount.to_f.round(2)}"
                       when "refund" then "+€#{tx.amount.to_f.round(2)}"
                       else "€#{tx.amount.to_f.round(2)}"
                       end

          {
            id: "TX-#{tx.id.to_s.rjust(3, '0')}",
            date: tx.created_at.strftime("%b %d"),
            type: type_label,
            amount: amount_str,
            job: tx.workload&.name || tx.transaction_type.humanize,
            status: tx.status
          }
        end
      end
    end
  end
end
