class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @google_accounts = current_user.google_accounts.includes(:accessible_customers)
    @active_selection = current_user.active_customer_selection
  end
end

