require "ostruct"

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    # GATE: If user has active subscription but no Google account connected → prompt to connect
    if current_user.subscribed? && !current_user.google_connected?
      # User paid but hasn't connected Google yet
      # Let them see the dashboard with the connect prompt
    end

    # Pós-pagamento: se tem plano ativo + Google conectado mas não escolheu contas do plano ainda
    if current_user.subscribed? && current_user.google_connected?
      ga = current_user.google_accounts.first
      plan = current_user.current_plan

      # Check if user has selected plan accounts (active accounts in DB)
      active_count = ga.active_accessible_customers.count if ga

      if active_count == 0 && ga&.accessible_customers&.any? && plan && !plan.unlimited? && !current_user.allowed?
        # User has Google connected but hasn't chosen which accounts for the plan
        session[:pending_google_account_id] = ga.id
        session[:accessible_customer_ids] = ga.accessible_customers.pluck(:customer_id)
        session[:selected_plan_id] = current_user.user_subscription&.plan_id
        redirect_to google_ads_select_active_accounts_path, notice: "Escolha as contas para usar no seu plano."
        return
      end

      # Has active accounts but no primary account selected
      if current_user.active_customer_selection.blank? && (active_count > 0 || current_user.allowed? || plan&.unlimited?)
        session[:pending_google_account_id] = ga.id
        session[:accessible_customer_ids] = ga.accessible_customers.pluck(:customer_id)
        session[:selected_plan_id] = current_user.user_subscription&.plan_id
        redirect_to google_ads_select_account_path, notice: "Escolha a conta principal para continuar."
        return
      end
    end

    @google_accounts = current_user.google_accounts.includes(:accessible_customers)
    @active_selection = current_user.active_customer_selection
    @pagy, @activity_logs = pagy(current_user.activity_logs.recent, items: 5)

    # Automatically fetch customer names if any are missing
    fetch_missing_customer_names if @google_accounts.any?
  end

  # Endpoint para retornar conteúdo da aba Dashboard (activity log)
  def activity_log
    @pagy, @activity_logs = pagy(current_user.activity_logs.recent, limit: 5)
    render partial: "dashboard/activity_log", layout: false
  end

  # Endpoint para retornar conteúdo da aba Account
  def account
    @google_accounts = current_user.google_accounts.includes(:accessible_customers)
    @active_selection = current_user.active_customer_selection
    fetch_missing_customer_names if @google_accounts.any?
    render partial: "dashboard/account_tab", layout: false
  end

  # Endpoint para retornar conteúdo da aba Leads
  def leads
    unless current_user.account_setup_complete?
      return render plain: onboarding_incomplete_html, status: :forbidden, content_type: "text/html"
    end

    @active_selection = current_user.active_customer_selection
    render partial: "dashboard/leads_section", layout: false
  end

  # Endpoint para retornar conteúdo da aba Campaigns
  def campaigns
    unless current_user.account_setup_complete?
      return render plain: onboarding_incomplete_html, status: :forbidden, content_type: "text/html"
    end

    @active_selection = current_user.active_customer_selection
    render partial: "dashboard/campaigns_section", layout: false
  end

  private

  def fetch_missing_customer_names
    # Don't fetch automatically - causes permission errors and is slow
    # Users can use the "Busca inteligente" button when needed
    Rails.logger.info("[DashboardController] Automatic name fetching disabled to avoid permission errors")
  end

  def onboarding_incomplete_html
    <<~HTML
      <div class="text-center py-16">
        <div class="mx-auto w-16 h-16 bg-amber-100 rounded-full flex items-center justify-center mb-4">
          <svg class="w-8 h-8 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"/>
          </svg>
        </div>
        <h3 class="text-lg font-bold text-slate-900 mb-2">Complete a configuração da sua conta</h3>
        <p class="text-sm text-slate-600 max-w-md mx-auto mb-6">
          Para acessar Leads e Campanhas, você precisa primeiro conectar sua conta Google Ads e selecionar a conta do seu plano.
        </p>
        <a href="/dashboard" class="inline-flex items-center gap-2 px-6 py-3 bg-indigo-600 text-white text-sm font-semibold rounded-xl hover:bg-indigo-700 transition-all">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <span>Ir para Configuração</span>
        </a>
      </div>
    HTML
  end
end
