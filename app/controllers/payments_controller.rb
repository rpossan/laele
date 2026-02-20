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

  # Payment confirmation page (legacy - kept for compatibility)
  def confirm
    @plan = Plan.find_by(id: params[:plan_id])
    @selected_accounts_count = params[:selected_accounts_count].to_i

    unless @plan
      redirect_to pricing_path, alert: "Plano não encontrado."
      return
    end

    # If plan has a payment link, redirect directly to it
    if @plan.stripe_payment_link.present?
      redirect_to @plan.payment_link_url_for(current_user), allow_other_host: true
      return
    end

    @calculated_price_brl = @plan.calculate_price_brl(@selected_accounts_count) / 100.0
    @calculated_price_usd = @plan.calculate_price_usd(@selected_accounts_count) / 100.0
  end

  def checkout
    plan = Plan.active.find_by(id: params[:plan_id])

    unless plan
      redirect_to pricing_path, alert: "Plano não encontrado."
      return
    end

    # If plan has a Stripe Payment Link, redirect to it
    if plan.stripe_payment_link.present?
      redirect_to plan.payment_link_url_for(current_user), allow_other_host: true
      return
    end

    # Legacy: Stripe Checkout Session flow (for plans without payment links)
    selected_accounts_count = params[:selected_accounts_count].to_i
    selected_accounts_count = 1 if selected_accounts_count < 1

    currency = params[:currency] || "brl"
    stripe_price_id = currency == "usd" ? plan.stripe_price_id_usd : plan.stripe_price_id_brl

    quantity = plan.per_account? ? selected_accounts_count : 1

    stripe_customer = find_or_create_stripe_customer

    line_items = [ {
      price: stripe_price_id,
      quantity: quantity
    } ]

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

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[PaymentsController] Stripe error: #{e.message}")
    redirect_to pricing_path, alert: "Erro no checkout: #{e.message}"
  end

  # Success page - shown after returning from Stripe Payment Link or Checkout
  # The actual subscription activation happens via webhook
  def success
    @subscription = current_user.user_subscription
    @plan = @subscription&.plan

    # Try to retrieve checkout session if provided
    session_id = params[:session_id]
    if session_id.present?
      begin
        @session = Stripe::Checkout::Session.retrieve(session_id)
      rescue Stripe::StripeError => e
        Rails.logger.error("[PaymentsController] Error retrieving session: #{e.message}")
        @session = nil
      end
    end
  end

  # Cancel page
  def cancel
    # User cancelled the checkout
  end

  # Customer portal for managing subscription
  def portal
    subscription = current_user.user_subscription

    unless subscription&.stripe_customer_id.present?
      redirect_to dashboard_path, alert: "Nenhuma assinatura encontrada."
      return
    end

    portal_session = Stripe::BillingPortal::Session.create({
      customer: subscription.stripe_customer_id,
      return_url: dashboard_url
    })

    redirect_to portal_session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[PaymentsController] Portal error: #{e.message}")
    redirect_to dashboard_path, alert: "Erro ao abrir portal de pagamentos."
  end

  private

  def find_or_create_stripe_customer
    subscription = current_user.user_subscription

    if subscription&.stripe_customer_id.present?
      Stripe::Customer.retrieve(subscription.stripe_customer_id)
    else
      Stripe::Customer.create({
        email: current_user.email,
        metadata: {
          user_id: current_user.id
        }
      })
    end
  end
end
