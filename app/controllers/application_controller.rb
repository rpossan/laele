class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale
  before_action :set_active_customer_context
  # Block access for users that are not explicitly allowed (admin controls `allowed` flag in DB)
  before_action :ensure_allowed_user

  helper_method :active_customer_context

  private

  def set_locale
    # Check if locale is set in session
    if session[:locale].present?
      I18n.locale = session[:locale]
    # Check Accept-Language header from browser
    elsif request.env["HTTP_ACCEPT_LANGUAGE"].present?
      browser_locale = extract_locale_from_accept_language
      I18n.locale = browser_locale if browser_locale.present?
    else
      # Default to English
      I18n.locale = :en
    end
  end

  def extract_locale_from_accept_language
    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"] || ""
    # Parse Accept-Language header (e.g., "pt-BR,pt;q=0.9,en;q=0.8")
    locales = accept_language.scan(/[a-z]{2}(?:-[A-Z]{2})?/i).map { |l| l.downcase }

    # Map browser locales to our supported locales
    locales.each do |locale|
      case locale
      when /^pt/
        return :'pt-BR'
      when /^en/
        return :en
      end
    end

    # Default to English if no match
    :en
  end

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

  def ensure_allowed_user
    # Only apply when user is signed in
    return unless user_signed_in?
    # Allow if explicitly allowed
    return if current_user.allowed?

    # Allow public pages and logout to avoid redirect loops
    return if request.path == privacy_path || request.path == pending_path || request.path == destroy_user_session_path
    return if request.path.start_with?("/assets") || request.path.start_with?("/rails") || request.path.start_with?("/locale") || request.path.start_with?("/up")

    redirect_to pending_path
  end
end
