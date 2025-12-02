require "ostruct"

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @google_accounts = current_user.google_accounts.includes(:accessible_customers)
    @active_selection = current_user.active_customer_selection
    @activity_logs = current_user.activity_logs.recent.limit(50)
    
    Rails.logger.info("[DashboardController] Active selection: #{@active_selection.inspect}")
    Rails.logger.info("[DashboardController] Google accounts count: #{@google_accounts.count}")
    
    # Automatically fetch customer names if any are missing
    fetch_missing_customer_names if @google_accounts.any?
  end

  # Endpoint para retornar conteúdo da aba Dashboard (activity log)
  def activity_log
    @activity_logs = current_user.activity_logs.recent.limit(50)
    render partial: 'dashboard/activity_log', layout: false
  end

  # Endpoint para retornar conteúdo da aba Account
  def account
    @google_accounts = current_user.google_accounts.includes(:accessible_customers)
    @active_selection = current_user.active_customer_selection
    fetch_missing_customer_names if @google_accounts.any?
    render partial: 'dashboard/account_tab', layout: false
  end

  # Endpoint para retornar conteúdo da aba Leads
  def leads
    @active_selection = current_user.active_customer_selection
    render partial: 'dashboard/leads_section', layout: false
  end

  # Endpoint para retornar conteúdo da aba Campaigns
  def campaigns
    @active_selection = current_user.active_customer_selection
    render partial: 'dashboard/campaigns_section', layout: false
  end

  private

  def fetch_missing_customer_names
    # Only fetch name for the active selection, not all customers
    return unless @active_selection
    
    active_customer = @active_selection.google_account.accessible_customers.find_by(customer_id: @active_selection.customer_id)
    
    return if active_customer.nil? || active_customer.display_name.present?
    
    Rails.logger.info("[DashboardController] Fetching name for active customer: #{@active_selection.customer_id}")
    
    begin
      # Use the customer_id itself as login_customer_id to avoid permission issues
      temp_account = OpenStruct.new(
        refresh_token: @active_selection.google_account.refresh_token,
        login_customer_id: @active_selection.customer_id
      )
      
      service = ::GoogleAds::CustomerService.new(google_account: temp_account)
      details = service.fetch_customer_details(@active_selection.customer_id)
      
      if details && details[:descriptive_name].present?
        active_customer.update(display_name: details[:descriptive_name])
        Rails.logger.info("[DashboardController] ✅ Fetched name for active customer #{@active_selection.customer_id}: #{details[:descriptive_name]}")
        
        # Reload to get updated name
        @google_accounts = current_user.google_accounts.includes(:accessible_customers).reload
      end
    rescue => e
      Rails.logger.warn("[DashboardController] Could not fetch name for active customer #{@active_selection.customer_id}: #{e.message}")
    end
  end
end

