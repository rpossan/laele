class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, raise: false
  protect_from_forgery except: :stripe

  def stripe
    # payload = request.body.read
    # payload =  request.raw_post
    # sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    # endpoint_secret = ENV["STRIPE_WEBHOOK_SECRET"]

    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV["STRIPE_SECRET_KEY"]

    # Diagnostic logging
    Rails.logger.info("[Webhook] Received request. Signature present: #{sig_header.present?}, Secret configured: #{endpoint_secret.present?}, Secret prefix: #{endpoint_secret&.first(10)}..., Payload size: #{payload.bytesize} bytes")

    # Log helpful diagnostic info when webhook secret is missing
    if endpoint_secret.blank? && !Rails.env.development?
      Rails.logger.error("[Webhook] ❌ STRIPE_WEBHOOK_SECRET is not configured! Webhook cannot be verified.")
      head :bad_request
      return
    end

    begin
      # In development, allow bypassing signature verification for testing
      if Rails.env.development? && sig_header.blank?
        Rails.logger.warn("[Webhook] ⚠️ DEV MODE: Skipping signature verification")
        event = Stripe::Event.construct_from(JSON.parse(payload, symbolize_names: true))
      else
        event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
      end
    rescue JSON::ParserError => e
      Rails.logger.error("[Webhook] Invalid payload: #{e.message}")
      head :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("[Webhook] ❌ Invalid signature: #{e.message}")
      Rails.logger.error("[Webhook] Sig header: #{sig_header&.first(50)}...")
      Rails.logger.error("[Webhook] Secret starts with: #{endpoint_secret&.first(10)}...")
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

    # Payment Links use client_reference_id to identify the user
    # Custom Checkout Sessions use metadata
    user_id = session.client_reference_id ||
              session.metadata&.[]("user_id") ||
              session.metadata&.user_id

    user = User.find_by(id: user_id)

    unless user
      # Try to find user by email from the session
      customer_email = session.customer_details&.email || session.customer_email
      user = User.find_by(email: customer_email) if customer_email.present?
    end

    unless user
      Rails.logger.error("[Webhook] User not found: client_reference_id=#{session.client_reference_id}, metadata=#{session.metadata.to_h}")
      return
    end

    Rails.logger.info("[Webhook] Found user #{user.id} (#{user.email}) for checkout session")

    # Find the user's subscription (created when they selected a plan)
    subscription = user.user_subscription

    # If no subscription exists, try to find the plan from the payment link
    unless subscription
      plan = find_plan_from_session(session)

      if plan
        Rails.logger.info("[Webhook] Creating subscription from payment link for user #{user.id}, plan: #{plan.slug}")
        subscription = user.build_user_subscription(
          plan: plan,
          selected_accounts_count: plan.max_accounts || 999,
          status: "pending"
        )
        subscription.save!
      else
        Rails.logger.error("[Webhook] No subscription found and could not determine plan for user #{user.id}")
        return
      end
    end

    plan = subscription.plan

    unless plan
      Rails.logger.error("[Webhook] No plan found for subscription of user #{user.id}")
      return
    end

    # Activate the subscription
    subscription.update!(
      status: "active",
      stripe_customer_id: session.customer,
      stripe_subscription_id: session.subscription,
      calculated_price_cents_brl: plan.price_cents_brl,
      calculated_price_cents_usd: plan.price_cents_usd,
      started_at: Time.current,
      expires_at: nil,
      cancelled_at: nil
    )

    # Grant access to the user
    user.update!(allowed: true)

    Rails.logger.info("[Webhook] ✅ Subscription activated for user #{user.id} (#{user.email}), plan: #{plan.name}, accounts: #{subscription.selected_accounts_count}")
  end

  def handle_subscription_updated(subscription_obj)
    Rails.logger.info("[Webhook] Subscription updated: #{subscription_obj.id}")

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_obj.id)

    unless user_subscription
      # Try to find by stripe_customer_id
      user_subscription = UserSubscription.find_by(stripe_customer_id: subscription_obj.customer)
    end

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
      stripe_subscription_id: subscription_obj.id,
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

    unless user_subscription
      user_subscription = UserSubscription.find_by(stripe_customer_id: subscription_obj.customer)
    end

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

    subscription_id = invoice.parent&.subscription_details&.subscription
    return unless subscription_id

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_id)

    unless user_subscription
      user_subscription = UserSubscription.find_by(stripe_customer_id: invoice.customer)
    end

    return unless user_subscription

    # Ensure subscription is active
    user_subscription.update!(status: "active")
    user_subscription.user.update!(allowed: true)

    Rails.logger.info("[Webhook] Payment confirmed for user #{user_subscription.user_id}")
  end

  def handle_invoice_payment_failed(invoice)
    Rails.logger.info("[Webhook] Invoice payment failed: #{invoice.id}")

    subscription_id = invoice.parent&.subscription_details&.subscription
    return unless subscription_id

    user_subscription = UserSubscription.find_by(stripe_subscription_id: subscription_id)

    unless user_subscription
      user_subscription = UserSubscription.find_by(stripe_customer_id: invoice.customer)
    end

    return unless user_subscription

    # Mark as past_due, user can still access for a grace period
    user_subscription.update!(status: "past_due")

    Rails.logger.info("[Webhook] Payment failed for user #{user_subscription.user_id}")
  end

  # Try to find the plan from a Stripe checkout session
  # Payment Links include the payment link URL which we can match against our plans
  def find_plan_from_session(session)
    # Try metadata first
    plan_id = session.metadata&.[]("plan_id") || session.metadata&.plan_id
    return Plan.find_by(id: plan_id) if plan_id.present?

    # Try to match by payment link ID
    if session.respond_to?(:payment_link) && session.payment_link.present?
      payment_link_id = session.payment_link.is_a?(String) ? session.payment_link : session.payment_link.id
      plan = Plan.active.find_by("stripe_payment_link LIKE ?", "%#{payment_link_id}%")
      return plan if plan
    end

    # Try to match by amount (last resort)
    if session.amount_total.present?
      amount_cents = session.amount_total
      plan = Plan.active.find_by(price_cents_brl: amount_cents)
      return plan if plan
    end

    nil
  end
end
