require "ostruct"

module GoogleAds
  class ConnectionsController < ApplicationController
    before_action :authenticate_user!, except: [ :callback ]
    before_action :set_google_account, only: :destroy

    # ──────────────────────────────────────────────────────────────────────────
    # FLOW ENFORCEMENT SUMMARY
    #
    # Correct user flow:
    #   1. Sign up (email + password)
    #   2. Select plan on pricing page → Pay via Stripe
    #   3. Payment OK (webhook activates subscription)
    #   4. Connect Google account (OAuth)
    #   5. Select which sub-accounts to use in the plan (select_active_accounts)
    #   6. Choose main/primary account (select_account)
    #   7. Dashboard ready
    #
    # Rules:
    #   - Without active subscription → blocked everywhere (RequireActiveSubscription)
    #   - Google connect only after payment confirmed
    #   - Account switch only shows plan-selected accounts (active=true in DB)
    # ──────────────────────────────────────────────────────────────────────────

    def start
      # GATE: Only allow Google connect after payment is confirmed
      unless current_user.subscribed?
        redirect_to pricing_path, alert: "Conclua o pagamento antes de conectar sua conta Google."
        return
      end

      session[:google_ads_state] = SecureRandom.hex(16)
      session[:google_ads_user_id] = current_user.id
      session[:google_login_customer_id] = params[:login_customer_id] if params[:login_customer_id].present?

      oauth_client = ::GoogleAds::OauthClient.new
      redirect_to oauth_client.authorization_url(state: session[:google_ads_state]), allow_other_host: true
    end

    def callback
      if params[:error].present?
        redirect_to new_user_session_path, alert: "Conexão cancelada: #{params[:error_description] || params[:error]}"
        return
      end

      unless params[:state] == session.delete(:google_ads_state)
        redirect_to new_user_session_path, alert: "State inválido na resposta do Google."
        return
      end

      user_id = session.delete(:google_ads_user_id)
      unless user_id
        redirect_to new_user_session_path, alert: "Sessão expirada. Por favor, tente conectar novamente."
        return
      end

      @user = User.find(user_id)
      sign_in(@user) unless user_signed_in?

      # GATE: Verify subscription is active
      unless @user.subscribed?
        redirect_to pricing_path, alert: "Conclua o pagamento antes de conectar sua conta Google."
        return
      end

      login_customer_id = session.delete(:google_login_customer_id)

      oauth_client = ::GoogleAds::OauthClient.new
      token_client = oauth_client.exchange_code(params[:code])

      # Find or create account
      if login_customer_id.present?
        google_account = @user.google_accounts.find_or_initialize_by(login_customer_id: login_customer_id)
      else
        google_account = @user.google_accounts.build
      end

      refresh_token = token_client.refresh_token

      if refresh_token.blank?
        redirect_to dashboard_path, alert: "O Google não retornou refresh token. Vá em myaccount.google.com/permissions e revogue o acesso."
        return
      end

      google_account.refresh_token = refresh_token
      google_account.scopes = token_client.scope.to_s.split(" ")
      google_account.save!

      # Fetch accessible customers from Google API
      service = GoogleAds::CustomerService.new(google_account: google_account)
      customer_ids = service.list_accessible_customers

      if customer_ids.empty?
        redirect_to dashboard_path, alert: "Nenhuma conta Google Ads encontrada nessa conta Google."
        return
      end

      # Store in session for the onboarding steps
      session[:pending_google_account_id] = google_account.id
      session[:accessible_customer_ids] = customer_ids

      subscription = @user.user_subscription
      plan = subscription&.plan

      # Create AccessibleCustomer records from the API — all inactive initially
      # User will pick which ones belong to the plan in select_active_accounts
      customer_ids.each do |cid|
        ac = google_account.accessible_customers.find_or_create_by(customer_id: cid)
        # For allowed (MVP) users or unlimited plans: auto-activate all
        if @user.allowed? || plan&.unlimited?
          ac.update!(active: true)
        else
          # Keep existing active status if already set (reconnection case)
          # Otherwise default to inactive
          ac.update!(active: false) if ac.active_changed? || ac.new_record?
        end
      end

      if @user.allowed?
        # Allowed users: skip account selection, activate all
        customer_ids.each do |cid|
          ac = google_account.accessible_customers.find_or_create_by(customer_id: cid)
          ac.update!(active: true)
        end
        session[:selected_plan_id] = subscription&.plan_id
        redirect_to google_ads_select_account_path, notice: "Conectado! Selecione a conta principal para continuar."
        return
      end

      if plan&.unlimited?
        # Unlimited plan: activate all, skip to main account selection
        session[:selected_plan_id] = subscription.plan_id
        redirect_to google_ads_select_account_path, notice: "Conectado! Selecione a conta principal para continuar."
      else
        # Limited plan: user must choose which accounts to include in the plan
        session[:selected_plan_id] = subscription&.plan_id
        # Deactivate all first so user picks fresh
        google_account.accessible_customers.update_all(active: false)
        redirect_to google_ads_select_active_accounts_path, notice: "Escolha até #{plan&.max_accounts || 1} conta(s) para usar no seu plano."
      end

    rescue Signet::AuthorizationError => e
      error_message = if e.message.include?("invalid_grant")
        "Código de autorização inválido ou expirado. Por favor, tente conectar novamente."
      else
        "Falha ao trocar o código por token: #{e.message}"
      end
      redirect_to dashboard_path, alert: error_message
    rescue ::Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      redirect_to dashboard_path, alert: "Google Ads API retornou erro: #{e.message}"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to dashboard_path, alert: "Erro ao salvar conta: #{e.message}"
    end

    # REMOVED: select_plan and save_plan_selection
    # Plan selection now happens on the pricing page BEFORE Google connect.
    # These are no longer needed in the Google Ads flow.

    def select_active_accounts
      # GATE: Must have active subscription
      unless current_user.subscribed?
        redirect_to pricing_path, alert: "Conclua o pagamento primeiro."
        return
      end

      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]
      plan_id = session[:selected_plan_id] || current_user.user_subscription&.plan_id

      unless google_account_id && customer_ids
        # Try to recover from DB if session expired but user has a Google account
        ga = current_user.google_accounts.first
        if ga && ga.accessible_customers.any?
          google_account_id = ga.id
          customer_ids = ga.accessible_customers.pluck(:customer_id)
          session[:pending_google_account_id] = google_account_id
          session[:accessible_customer_ids] = customer_ids
          plan_id ||= current_user.user_subscription&.plan_id
          session[:selected_plan_id] = plan_id
        else
          redirect_to dashboard_path, alert: "Sessão expirada. Por favor, conecte sua conta Google novamente."
          return
        end
      end

      @google_account = current_user.google_accounts.find(google_account_id)
      @customer_ids = customer_ids
      @plan = Plan.find(plan_id) if plan_id

      unless @plan
        redirect_to pricing_path, alert: "Nenhum plano encontrado. Selecione um plano primeiro."
        return
      end

      # For unlimited plans, skip this step
      if @plan.unlimited?
        @google_account.accessible_customers.update_all(active: true)
        redirect_to google_ads_select_account_path, notice: "Todas as contas foram ativadas. Escolha a conta principal."
        return
      end

      # Calculate max accounts allowed
      @max_accounts = @plan.max_accounts || customer_ids.count
      @is_per_account = @plan.per_account?
      @price_per_account = @plan.price_per_account_brl if @is_per_account

      # Fetch customer names for display
      @customer_names = fetch_customer_names(@google_account, customer_ids)
    end

    def save_active_accounts
      # GATE: Must have active subscription
      unless current_user.subscribed?
        redirect_to pricing_path, alert: "Conclua o pagamento primeiro."
        return
      end

      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]
      plan_id = session[:selected_plan_id] || current_user.user_subscription&.plan_id
      selected_ids = params[:selected_customer_ids] || []

      # Ensure selected_ids is an array
      selected_ids = [ selected_ids ] unless selected_ids.is_a?(Array)
      selected_ids = selected_ids.reject(&:blank?)

      unless google_account_id && customer_ids
        redirect_to dashboard_path, alert: "Sessão expirada. Por favor, conecte sua conta Google novamente."
        return
      end

      plan = Plan.find(plan_id) if plan_id

      unless plan
        redirect_to pricing_path, alert: "Nenhum plano encontrado."
        return
      end

      # Validate selection
      if selected_ids.empty?
        redirect_to google_ads_select_active_accounts_path, alert: "Selecione pelo menos uma conta para ativar."
        return
      end

      # Check plan limits strictly
      if plan.max_accounts && selected_ids.count > plan.max_accounts
        redirect_to google_ads_select_active_accounts_path, alert: "Este plano permite no máximo #{plan.max_accounts} contas. Você selecionou #{selected_ids.count}."
        return
      end

      # Update DB: set active status based on selection (single source of truth)
      google_account = current_user.google_accounts.find(google_account_id)
      google_account.accessible_customers.each do |ac|
        ac.update!(active: selected_ids.include?(ac.customer_id))
      end

      # Update subscription account count
      subscription = current_user.user_subscription
      if subscription
        subscription.update!(selected_accounts_count: selected_ids.count)
      end

      redirect_to google_ads_select_account_path, notice: "#{selected_ids.count} conta(s) selecionada(s)! Agora escolha qual será sua conta principal."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to google_ads_select_active_accounts_path, alert: "Erro ao salvar: #{e.message}"
    end

    def select_account
      # GATE: Must have active subscription
      unless current_user.subscribed?
        redirect_to pricing_path, alert: "Conclua o pagamento primeiro."
        return
      end

      google_account_id = session[:pending_google_account_id]

      # Try to recover from DB if session expired
      unless google_account_id
        ga = current_user.google_accounts.first
        if ga
          google_account_id = ga.id
          session[:pending_google_account_id] = ga.id
          session[:accessible_customer_ids] = ga.accessible_customers.pluck(:customer_id)
          session[:selected_plan_id] = current_user.user_subscription&.plan_id
        else
          redirect_to dashboard_path, alert: "Conecte sua conta Google primeiro."
          return
        end
      end

      @google_account = current_user.google_accounts.find(google_account_id)
      @selected_plan = current_user.user_subscription&.plan

      # STRICT: Only show accounts that are active in the plan (DB is truth)
      if @selected_plan&.unlimited? || current_user.allowed?
        @active_customer_ids = @google_account.accessible_customers.pluck(:customer_id)
      else
        @active_customer_ids = @google_account.active_accessible_customers.pluck(:customer_id)
      end

      # Must have at least one active account
      if @active_customer_ids.empty?
        redirect_to google_ads_select_active_accounts_path, alert: "Selecione pelo menos uma conta para continuar."
        return
      end

      @customer_ids = @active_customer_ids
      @selected_accounts_count = @active_customer_ids.count

      # Fetch customer names for display
      @customer_names = fetch_customer_names(@google_account, @active_customer_ids)
    end

    def save_account_selection
      google_account_id = params[:google_account_id]
      selected_customer_id = params[:login_customer_id]
      customer_names_json = params[:customer_names]

      unless google_account_id.present? && selected_customer_id.present?
        redirect_to dashboard_path, alert: "Parâmetros inválidos."
        return
      end

      google_account = current_user.google_accounts.find(google_account_id)
      plan = current_user.current_plan

      # STRICT: Only allow selecting an account that is active in the plan (DB is truth)
      unless current_user.allowed?
        if plan.present? && !plan.unlimited?
          allowed_ids = google_account.active_accessible_customers.pluck(:customer_id)
          unless allowed_ids.include?(selected_customer_id)
            redirect_to google_ads_select_account_path, alert: "Esta conta não está incluída no seu plano. Escolha uma das contas selecionadas."
            return
          end
        end
      end

      # Parse customer names from form
      customer_names = {}
      begin
        customer_names = JSON.parse(customer_names_json) if customer_names_json.present?
      rescue => e
        Rails.logger.warn("[GoogleAds::ConnectionsController] Failed to parse customer_names: #{e.message}")
      end

      # Check if account with this login_customer_id already exists
      existing_account = current_user.google_accounts.where(login_customer_id: selected_customer_id).where.not(id: google_account.id).first

      if existing_account
        # Merge: delete the new account and use the existing one
        google_account.destroy
        google_account = existing_account
      else
        # Update the account with the selected login_customer_id
        google_account.update!(login_customer_id: selected_customer_id)
      end

      # Set manager_customer_id once
      unless google_account.manager_customer_id.present?
        google_account.update!(manager_customer_id: selected_customer_id)
        Rails.logger.info("[GoogleAds::ConnectionsController] Set manager_customer_id to #{selected_customer_id}")
      end

      # Create or update ActiveCustomerSelection
      selection = current_user.active_customer_selection || current_user.build_active_customer_selection
      selection.customer_id = selected_customer_id
      selection.google_account = google_account

      unless selection.save
        Rails.logger.error("[GoogleAds::ConnectionsController] Failed to save ActiveCustomerSelection: #{selection.errors.full_messages.join(', ')}")
        redirect_to dashboard_path, alert: "Erro ao salvar seleção: #{selection.errors.full_messages.join(', ')}"
        return
      end

      session[:active_customer_id] = selection.customer_id
      session[:active_google_account_id] = selection.google_account_id

      # Save customer names from form to DB (do NOT re-fetch or override active statuses)
      begin
        customer_names.each do |customer_id, display_name|
          ac = google_account.accessible_customers.find_by(customer_id: customer_id)
          if ac && display_name.present? && ac.display_name.blank?
            ac.update!(display_name: display_name)
          end
        end
      rescue => e
        Rails.logger.warn("[GoogleAds::ConnectionsController] Could not save customer names: #{e.message}")
      end

      # Log activity
      ActivityLogger.log_account_connected(
        user: current_user,
        login_customer_id: google_account.login_customer_id || selected_customer_id,
        request: request
      )

      # Clear session data
      clear_plan_session_data

      redirect_to leads_path, notice: "Conta Google Ads conectada com sucesso!"
    end

    def change_plan
      @current_subscription = current_user.user_subscription
      unless @current_subscription
        redirect_to pricing_path, alert: "Você ainda não tem um plano. Por favor, selecione um."
        return
      end

      @current_plan = @current_subscription.plan
      @plans = Plan.active.ordered
      @google_account = current_user.google_accounts.first

      unless @google_account
        redirect_to dashboard_path, alert: "Você precisa conectar uma conta Google Ads primeiro."
        return
      end

      # Get all accessible customers for this account
      @all_customer_ids = @google_account.accessible_customers.pluck(:customer_id)
      @active_customer_ids = @google_account.accessible_customers.active.pluck(:customer_id)
      @accounts_count = @all_customer_ids.count

      # Fetch customer names for display
      @customer_names = @google_account.accessible_customers.pluck(:customer_id, :display_name).to_h
    end

    def save_change_plan
      plan_id = params[:plan_id]
      selected_ids = params[:selected_customer_ids] || []

      # Ensure selected_ids is an array
      selected_ids = [ selected_ids ] unless selected_ids.is_a?(Array)
      selected_ids = selected_ids.reject(&:blank?)

      unless plan_id.present?
        redirect_to google_ads_change_plan_path, alert: "Selecione um plano."
        return
      end

      plan = Plan.active.find(plan_id)

      # Validate selection
      if selected_ids.empty?
        redirect_to google_ads_change_plan_path, alert: "Selecione pelo menos uma conta para ativar."
        return
      end

      # Check plan limits
      if plan.max_accounts && selected_ids.count > plan.max_accounts
        redirect_to google_ads_change_plan_path, alert: "Este plano permite no máximo #{plan.max_accounts} contas. Você selecionou #{selected_ids.count}."
        return
      end

      # Update or create subscription
      subscription = current_user.user_subscription || current_user.build_user_subscription
      subscription.plan = plan
      subscription.selected_accounts_count = selected_ids.count
      subscription.status = "pending" # Payment will need to confirm
      subscription.save!

      # Update active status on accessible_customers (DB = single source of truth)
      google_account = current_user.google_accounts.first
      if google_account
        google_account.accessible_customers.each do |ac|
          is_active = selected_ids.include?(ac.customer_id)
          ac.update!(active: is_active)
        end
      end

      # Clear active customer selection (user must re-select from new plan accounts)
      current_user.active_customer_selection&.destroy

      # Redirect to Stripe Payment Link for payment
      if plan.stripe_payment_link.present?
        payment_url = plan.payment_link_url_for(current_user)
        redirect_to payment_url, allow_other_host: true
      else
        # No payment link configured - activate directly (dev mode)
        subscription.update!(status: "active", started_at: Time.current)
        redirect_to dashboard_path, notice: "Plano alterado com sucesso! #{selected_ids.count} conta(s) ativa(s)."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to google_ads_change_plan_path, alert: "Plano não encontrado."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to google_ads_change_plan_path, alert: "Erro ao salvar: #{e.message}"
    end

    def destroy
      login_customer_id = @google_account.login_customer_id
      @google_account.destroy!

      # Log activity
      ActivityLogger.log_account_disconnected(
        user: current_user,
        login_customer_id: login_customer_id,
        request: request
      )

      redirect_to dashboard_path, notice: "Conexão removida."
    end

    def switch_customer
      # Permite trocar de customer_id (dentro das contas do plano apenas)
      google_account_id = params[:google_account_id]
      new_customer_id = params[:customer_id]

      unless google_account_id.present? && new_customer_id.present?
        return render json: { error: "Parâmetros inválidos" }, status: :bad_request
      end

      google_account = current_user.google_accounts.find(google_account_id)

      # STRICT: Only allow switching to accounts that are ACTIVE in the plan
      accessible = google_account.accessible_customers.find_by(customer_id: new_customer_id)
      unless accessible
        return render json: { error: "Conta não encontrada" }, status: :forbidden
      end

      # For non-allowed users with limited plans: enforce active-only
      unless current_user.allowed?
        plan = current_user.current_plan
        if plan.present? && !plan.unlimited?
          unless accessible.active?
            return render json: {
              error: "Esta conta não está incluída no seu plano. Você só pode trocar entre as contas selecionadas no plano."
            }, status: :forbidden
          end
        end
      end

      # Update the selection
      selection = current_user.active_customer_selection || current_user.build_active_customer_selection
      selection.customer_id = new_customer_id
      selection.google_account = google_account

      if selection.save
        session[:active_customer_id] = selection.customer_id
        session[:active_google_account_id] = selection.google_account_id

        Rails.logger.info("[GoogleAds::ConnectionsController] Switched to customer #{new_customer_id}")

        render json: {
          success: true,
          customer_id: new_customer_id,
          display_name: accessible.display_name
        }
      else
        render json: { error: selection.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end

    # Keep select_plan and save_plan_selection for backward compatibility with existing routes
    def select_plan
      # This flow is deprecated — plan selection happens on pricing page before Google connect
      redirect_to pricing_path, notice: "Selecione um plano na página de preços."
    end

    def save_plan_selection
      # Deprecated — plan selection happens on pricing page
      redirect_to pricing_path, alert: "Selecione um plano na página de preços."
    end

    helper_method :format_customer_id

    def format_customer_id(customer_id)
      return "N/A" unless customer_id.present?
      digits = customer_id.to_s.gsub(/\D/, "")
      "#{digits[0..2]}-#{digits[3..5]}-#{digits[6..-1]}"
    end

    private

    def set_google_account
      @google_account = current_user.google_accounts.find(params[:id])
    end

    def clear_plan_session_data
      session.delete(:pending_google_account_id)
      session.delete(:accessible_customer_ids)
      session.delete(:selected_plan_id)
      session.delete(:selected_customer_ids)
      session.delete(:skip_plan_selection)
      session.delete(:stripe_pending_subscription)
    end

    def fetch_customer_names(google_account, customer_ids)
      customer_names = {}

      return customer_names unless customer_ids.any?

      Rails.logger.info("[GoogleAds::ConnectionsController] Fetching names for #{customer_ids.count} customers in parallel")

      threads = []
      mutex = Mutex.new

      customer_ids.each do |customer_id|
        threads << Thread.new(customer_id) do |cid|
          begin
            temp_account = OpenStruct.new(
              refresh_token: google_account.refresh_token,
              login_customer_id: cid
            )

            temp_service = GoogleAds::CustomerService.new(google_account: temp_account)
            details = temp_service.fetch_customer_details(cid)

            if details && details[:descriptive_name].present?
              mutex.synchronize do
                customer_names[cid] = details[:descriptive_name]
                Rails.logger.info("[GoogleAds::ConnectionsController] ✅ Fetched name for #{cid}: #{details[:descriptive_name]}")
              end
            else
              Rails.logger.warn("[GoogleAds::ConnectionsController] No name found for #{cid}")
            end
          rescue => e
            Rails.logger.warn("[GoogleAds::ConnectionsController] Failed to fetch name for #{cid}: #{e.message}")
          end
        end
      end

      threads.each(&:join)

      Rails.logger.info("[GoogleAds::ConnectionsController] Successfully fetched #{customer_names.count} names out of #{customer_ids.count}")

      customer_names
    end
  end
end
