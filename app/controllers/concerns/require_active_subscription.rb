# Concern to enforce active subscription for protected controllers
module RequireActiveSubscription
  extend ActiveSupport::Concern

  included do
    before_action :ensure_active_subscription
  end

  private

  def ensure_active_subscription
    return unless user_signed_in?

    # Skip if user has an active subscription (or is allowed/MVP)
    return if current_user.subscribed?

    # Allow access to public pages
    return if public_path?

    # Allow access to payment-related paths
    return if payment_path?

    # Allow Devise paths
    return if devise_path?

    # Allow Google Ads onboarding paths ONLY after user has active subscription
    # (subscribed? check above already handles this, so if we reach here the user
    #  does NOT have an active sub — block everything including Google Ads)

    # Redirect to pricing: sem pagamento concluído o usuário não pode fazer nada (nem conectar Google)
    redirect_to pricing_path, alert: t("errors.subscription_required")
  end

  def public_path?
    # Root, pricing, privacy, landing, locale, pending, admin paths
    request.path == "/" ||
    request.path == "/pricing" ||
    request.path == "/privacy" ||
    request.path == "/pending" ||
    request.path.start_with?("/locale") ||
    request.path.start_with?("/assets") ||
    request.path.start_with?("/rails") ||
    request.path.start_with?("/up") ||
    request.path.start_with?("/admin")
  end

  def payment_path?
    request.path == "/billing" ||
    request.path.start_with?("/payments") ||
    request.path.start_with?("/webhooks")
  end

  def devise_path?
    request.path.start_with?("/users")
  end
end
