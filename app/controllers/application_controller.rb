class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_active_customer_context

  helper_method :active_customer_context

  private

  def set_active_customer_context
    return unless user_signed_in?

    selection = current_user.active_customer_selection

    if selection
      session[:active_customer_id] = selection.customer_id
      session[:active_google_account_id] = selection.google_account_id
      @active_customer_context = build_active_customer_context(selection)
    else
      session.delete(:active_customer_id)
      session.delete(:active_google_account_id)
      @active_customer_context = nil
    end
  end

  def build_active_customer_context(selection)
    accessible = selection.google_account.accessible_customers.find_by(customer_id: selection.customer_id)

    {
      customer_id: selection.customer_id,
      google_account_id: selection.google_account_id,
      login_customer_id: selection.google_account.login_customer_id,
      display_name: accessible&.display_name
    }
  end

  def active_customer_context
    @active_customer_context
  end
end
