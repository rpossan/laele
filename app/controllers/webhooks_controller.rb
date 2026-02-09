class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, raise: false

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = ENV["STRIPE_WEBHOOK_SECRET"]

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError => e
      Rails.logger.error("[Webhook] Invalid payload: #{e.message}")
      head :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("[Webhook] Invalid signature: #{e.message}")
      head :bad_request
      return
    end

    Rails.logger.info("[Webhook] Processing event: #{event.type}")

    case event.type
    when "checkout.session.completed"
      handle_checkout_session_completed(event.data.object)
    when "customer.subscription.updated"
      handle_subscription_updated(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    when "invoice.payment_succeeded"
      handle_invoice_payment_succeeded(event.data.object)
    when "invoice.payment_failed"
      handle_invoice_payment_failed(event.data.object)
    else
      Rails.logger.info("[Webhook] Unhandled event type: #{event.type}")
    end

    head :ok
  end

  private

  def handle_checkout_session_completed(session)
    Rails.logger.info("[Webhook] Checkout session completed: #{session.id}")

    user_id = session.metadata&.user_id || session.metadata&.[]("user_id")
    plan_id = session.metadata&.plan_id || session.metadata&.[]("plan_id")
    selected_accounts_count = session.metadata&.selected_accounts_count || session.metadata&.[]("selected_accounts_count")

    user = User.find_by(id: user_id)
    plan = Plan.find_by(id: plan_id)

    unless user && plan
      Rails.logger.error("[Webhook] User or Plan not found: user_id=#{user_id}, plan_id=#{plan_id}")
      return
    end

    # Get or create user subscription
    subscription = user.user_subscription || user.build_user_subscription

    # Update subscription with Stripe data
    subscription.update!(
      plan: plan,
      status: "active",
      stripe_customer_id: session.customer,
      stripe_subscription_id: session.subscription,
      selected_accounts_count: selected_accounts_count.to_i,
      calculated_price_cents_brl: plan.calculate_price_brl(selected_accounts_count.to_i),
      calculated_price_cents_usd: plan.calculate_price_usd(selected_accounts_count.to_i),
      started_at: Time.current,
      expires_at: nil, # Subscription-based, no fixed expiry
      cancelled_at: nil
    )

    # Update user allowed flag
    user.update!(allowed: true)

    Rails.logger.info("[Webhook] Subscription activated for user #{user.id}, plan #{plan.name}")
  end

  def handle_subscription_updated(subscription_obj)
    Rails.logger.info("[Webhook] Subscription updated: #{subscription_obj.id}")

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_obj.id)
    return unless user_subscription

    status = case subscription_obj.status
    when "active" then "active"
    when "past_due" then "past_due"
    when "canceled" then "cancelled"
    when "unpaid" then "unpaid"
    else subscription_obj.status
    end

    user_subscription.update!(
      status: status,
      expires_at: subscription_obj.cancel_at ? Time.at(subscription_obj.cancel_at) : nil
    )

    # Update user allowed flag based on status
    user = user_subscription.user
    user.update!(allowed: status == "active")

    Rails.logger.info("[Webhook] Subscription status updated to #{status} for user #{user.id}")
  end

  def handle_subscription_deleted(subscription_obj)
    Rails.logger.info("[Webhook] Subscription deleted: #{subscription_obj.id}")

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_obj.id)
    return unless user_subscription

    user_subscription.update!(
      status: "cancelled",
      cancelled_at: Time.current
    )

    # Revoke user access
    user = user_subscription.user
    user.update!(allowed: false)

    Rails.logger.info("[Webhook] Subscription cancelled for user #{user.id}")
  end

  def handle_invoice_payment_succeeded(invoice)
    Rails.logger.info("[Webhook] Invoice payment succeeded: #{invoice.id}")

    subscription_id = invoice.subscription
    return unless subscription_id

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_id)
    return unless user_subscription

    # Ensure subscription is active
    user_subscription.update!(status: "active")
    user_subscription.user.update!(allowed: true)

    Rails.logger.info("[Webhook] Payment confirmed for user #{user_subscription.user_id}")
  end

  def handle_invoice_payment_failed(invoice)
    Rails.logger.info("[Webhook] Invoice payment failed: #{invoice.id}")

    subscription_id = invoice.subscription
    return unless subscription_id

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_id)
    return unless user_subscription

    # Mark as past_due, user can still access for a grace period
    user_subscription.update!(status: "past_due")

    Rails.logger.info("[Webhook] Payment failed for user #{user_subscription.user_id}")
  end
end
