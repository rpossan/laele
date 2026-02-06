class PaymentsController < ApplicationController
  before_action :authenticate_user!

  # Billing area - subscription status, invoices, manage
  def billing
    @subscription = current_user.user_subscription
    @plan = @subscription&.plan

    # Fetch recent invoices from Stripe if customer exists
    @invoices = []
    if @subscription&.stripe_customer_id.present?
      begin
        @invoices = Stripe::Invoice.list({
          customer: @subscription.stripe_customer_id,
          limit: 5
        }).data
      rescue Stripe::StripeError => e
        Rails.logger.error("[PaymentsController] Error fetching invoices: #{e.message}")
      end

      # Fetch subscription details from Stripe
      if @subscription.stripe_subscription_id.present?
        begin
          @stripe_subscription = Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)
        rescue Stripe::StripeError => e
          Rails.logger.error("[PaymentsController] Error fetching subscription: #{e.message}")
        end
      end
    end
  end

  # Payment confirmation page before Stripe Checkout
  def confirm
    @plan = Plan.find_by(id: params[:plan_id])
    @selected_accounts_count = params[:selected_accounts_count].to_i

    unless @plan
      redirect_to pricing_path, alert: t("payments.plan_not_found")
      return
    end

    @calculated_price_brl = @plan.calculate_price_brl(@selected_accounts_count) / 100.0
    @calculated_price_usd = @plan.calculate_price_usd(@selected_accounts_count) / 100.0
  end

  def checkout
    plan = Plan.active.find_by(id: params[:plan_id])

    unless plan
      redirect_to pricing_path, alert: t("payments.plan_not_found")
      return
    end

    # Get selected accounts count from params or current subscription
    selected_accounts_count = params[:selected_accounts_count].to_i
    selected_accounts_count = 1 if selected_accounts_count < 1

    # Calculate price based on plan and accounts
    currency = params[:currency] || "brl"
    stripe_price_id = currency == "usd" ? plan.stripe_price_id_usd : plan.stripe_price_id_brl

    # For per-account plans, we need to handle quantity
    quantity = plan.per_account? ? selected_accounts_count : 1

    # Create or retrieve Stripe customer
    stripe_customer = find_or_create_stripe_customer

    # Build line items
    line_items = [ {
      price: stripe_price_id,
      quantity: quantity
    } ]

    # Create Stripe Checkout Session
    session = Stripe::Checkout::Session.create({
      customer: stripe_customer.id,
      mode: "subscription",
      line_items: line_items,
      success_url: payments_success_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: payments_cancel_url,
      metadata: {
        user_id: current_user.id,
        plan_id: plan.id,
        selected_accounts_count: selected_accounts_count,
        currency: currency
      },
      subscription_data: {
        metadata: {
          user_id: current_user.id,
          plan_id: plan.id,
          selected_accounts_count: selected_accounts_count
        }
      }
    })

    # Redirect to Stripe Checkout
    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[PaymentsController] Stripe error: #{e.message}")
    redirect_to pricing_path, alert: t("payments.checkout_error", error: e.message)
  end

  # Success page - only visual feedback, actual activation via webhook
  def success
    session_id = params[:session_id]
    if session_id.present?
      @session = Stripe::Checkout::Session.retrieve(session_id)
    end
    # Don't activate subscription here - wait for webhook
  rescue Stripe::StripeError => e
    Rails.logger.error("[PaymentsController] Error retrieving session: #{e.message}")
    @session = nil
  end

  # Cancel page
  def cancel
    # User cancelled the checkout
  end

  # Customer portal for managing subscription
  def portal
    subscription = current_user.user_subscription

    unless subscription&.stripe_customer_id.present?
      redirect_to dashboard_path, alert: t("payments.no_subscription")
      return
    end

    portal_session = Stripe::BillingPortal::Session.create({
      customer: subscription.stripe_customer_id,
      return_url: dashboard_url
    })

    redirect_to portal_session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[PaymentsController] Portal error: #{e.message}")
    redirect_to dashboard_path, alert: t("payments.portal_error")
  end

  private

  def find_or_create_stripe_customer
    subscription = current_user.user_subscription

    if subscription&.stripe_customer_id.present?
      # Retrieve existing customer
      Stripe::Customer.retrieve(subscription.stripe_customer_id)
    else
      # Create new customer
      Stripe::Customer.create({
        email: current_user.email,
        metadata: {
          user_id: current_user.id
        }
      })
    end
  end
end
