require "ostruct"

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @google_accounts = current_user.google_accounts.includes(:accessible_customers)
    @active_selection = current_user.active_customer_selection
    @pagy, @activity_logs = pagy(current_user.activity_logs.recent, items: 5)
    
    
    # Automatically fetch customer names if any are missing
    fetch_missing_customer_names if @google_accounts.any?
  end

  # Endpoint para retornar conteúdo da aba Dashboard (activity log)
  def activity_log
    @pagy, @activity_logs = pagy(current_user.activity_logs.recent, limit: 5)
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
    # Don't fetch automatically - causes permission errors and is slow
    # Users can use the "Busca inteligente" button when needed
    Rails.logger.info("[DashboardController] Automatic name fetching disabled to avoid permission errors")
  end
end

