# app/services/stripe_service.rb
#
# Stripe integration for B2B compute billing
# Handles: subscription setup, usage-based charges, invoicing
#
class StripeService
  class << self
    def create_customer(organization)
      return mock_customer(organization) unless stripe_live?

      customer = Stripe::Customer.create(
        email: organization.contact_email,
        name: organization.name,
        metadata: { org_id: organization.id, tier: organization.tier }
      )

      organization.update!(stripe_customer_id: customer.id)
      customer
    end

    def charge_for_workload(transaction)
      return mock_charge(transaction) unless stripe_live?

      intent = Stripe::PaymentIntent.create(
        amount: (transaction.amount * 100).to_i, # cents
        currency: transaction.currency.downcase,
        customer: transaction.organization.stripe_customer_id,
        metadata: {
          workload_id: transaction.workload_id,
          transaction_id: transaction.id,
          carbon_saved: transaction.workload&.carbon_saved_grams
        }
      )

      transaction.update!(stripe_payment_intent_id: intent.id, status: "completed")
      intent
    end

    def create_checkout_session(organization, tier:)
      return mock_checkout(organization) unless stripe_live?

      prices = {
        "starter" => ENV["STRIPE_STARTER_PRICE_ID"],
        "pro" => ENV["STRIPE_PRO_PRICE_ID"],
        "enterprise" => ENV["STRIPE_ENTERPRISE_PRICE_ID"]
      }

      Stripe::Checkout::Session.create(
        customer: organization.stripe_customer_id,
        mode: "subscription",
        line_items: [{ price: prices[tier], quantity: 1 }],
        success_url: "#{ENV['APP_URL']}/dashboard?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{ENV['APP_URL']}/pricing"
      )
    end

    private

    def stripe_live?
      ENV["STRIPE_SECRET_KEY"].present? && ENV["STRIPE_SECRET_KEY"] != "demo"
    end

    def mock_customer(organization)
      cid = "cus_demo_#{SecureRandom.hex(8)}"
      organization.update!(stripe_customer_id: cid)
      OpenStruct.new(id: cid)
    end

    def mock_charge(transaction)
      pi_id = "pi_demo_#{SecureRandom.hex(8)}"
      transaction.update!(stripe_payment_intent_id: pi_id, status: "completed")
      OpenStruct.new(id: pi_id, status: "succeeded")
    end

    def mock_checkout(organization)
      OpenStruct.new(url: "/dashboard", id: "cs_demo_#{SecureRandom.hex(8)}")
    end
  end
end
