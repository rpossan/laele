# Concern to enforce active subscription for protected controllers
module RequireActiveSubscription
  extend ActiveSupport::Concern

  included do
    before_action :ensure_active_subscription
  end

  private

  def ensure_active_subscription
    return unless user_signed_in?

    # Skip if user has an active subscription
    return if current_user.subscribed?

    # Allow access to public pages
    return if public_path?

    # Allow access to payment-related paths
    return if payment_path?

    # Allow access to Google Ads connection flow (needed to select plan)
    return if google_ads_connection_path?

    # Allow Devise paths
    return if devise_path?

    # Redirect to pricing page
    redirect_to pricing_path, alert: t("errors.subscription_required")
  end

  def public_path?
    # Root, pricing, privacy, landing, locale, pending paths
    request.path == "/" ||
    request.path == "/pricing" ||
    request.path == "/privacy" ||
    request.path == "/pending" ||
    request.path.start_with?("/locale") ||
    request.path.start_with?("/assets") ||
    request.path.start_with?("/rails") ||
    request.path.start_with?("/up")
  end

  def payment_path?
    request.path == "/billing" ||
    request.path.start_with?("/payments") ||
    request.path.start_with?("/webhooks")
  end

  def google_ads_connection_path?
    request.path.start_with?("/google_ads/auth") ||
    request.path.start_with?("/google_ads/plan")
  end

  def devise_path?
    request.path.start_with?("/users")
  end
end
