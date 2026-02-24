# Concern to ensure selected customer account is active in the user's plan
module EnsureActiveCustomer
  extend ActiveSupport::Concern

  included do
    before_action :ensure_active_customer, if: :customer_context_required?
  end

  private

  def ensure_active_customer
    # Users with allowed: true bypass all account restrictions (MVP/admin users)
    return if current_user&.allowed?

    # Must have active subscription
    return unless current_user&.subscribed?

    selection = current_user&.active_customer_selection
    return unless selection

    # Find the accessible customer record
    accessible_customer = selection.google_account&.accessible_customers&.find_by(
      customer_id: selection.customer_id
    )

    # If accessible customer exists but is not active, block the action
    if accessible_customer && !accessible_customer.active?
      # Check if the plan is unlimited (unlimited plans have all accounts active)
      plan = current_user.current_plan
      return if plan&.unlimited?

      handle_inactive_customer(accessible_customer)
    end
  end

  def handle_inactive_customer(accessible_customer)
    error_message = "A conta #{accessible_customer.effective_display_name} não está ativa no seu plano atual. Selecione outra conta."

    respond_to do |format|
      format.html { redirect_to dashboard_path, alert: error_message }
      format.json { render json: { error: error_message, code: "INACTIVE_ACCOUNT" }, status: :forbidden }
    end
  end

  def customer_context_required?
    # Override in specific controllers if needed
    true
  end
end
