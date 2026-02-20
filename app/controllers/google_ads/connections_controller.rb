require "ostruct"

module GoogleAds
  class ConnectionsController < ApplicationController
    before_action :authenticate_user!, except: [ :callback ]
    before_action :set_google_account, only: :destroy

    def start
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

      login_customer_id = session.delete(:google_login_customer_id)

      oauth_client = ::GoogleAds::OauthClient.new
      token_client = oauth_client.exchange_code(params[:code])

      # Find or create account - we'll set login_customer_id later after user selects
      if login_customer_id.present?
        google_account = @user.google_accounts.find_or_initialize_by(login_customer_id: login_customer_id)
      else
        # Create a new account without login_customer_id (will be set later)
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

      # Now fetch accessible customers using the refresh_token
      service = GoogleAds::CustomerService.new(google_account: google_account)
      customer_ids = service.list_accessible_customers

      if customer_ids.empty?
        redirect_to dashboard_path, alert: "Nenhuma conta Google Ads encontrada nessa conta Google."
        return
      end

      # Store customer_ids in session
      session[:pending_google_account_id] = google_account.id
      session[:accessible_customer_ids] = customer_ids

      # Check if user is allowed (MVP/admin bypass) - skip all plan selection
      if @user.allowed?
        # Allowed users get full access to all accounts without plan selection
        session[:selected_customer_ids] = customer_ids
        session[:skip_plan_selection] = true

        # Activate all accounts for allowed users
        customer_ids.each do |cid|
          ac = google_account.accessible_customers.find_or_create_by(customer_id: cid)
          ac.update(active: true)
        end

        redirect_to google_ads_select_account_path, notice: "Conectado! Selecione a conta principal para continuar."
        return
      end

      # Check if user already has an active subscription
      existing_subscription = @user.user_subscription
      if existing_subscription&.active?
        # User already has an active plan - skip plan selection, go directly to account selection
        session[:selected_plan_id] = existing_subscription.plan_id

        # Get previously active customer IDs from accessible_customers
        active_customer_ids = google_account.accessible_customers.active.pluck(:customer_id)
        if active_customer_ids.any?
          session[:selected_customer_ids] = active_customer_ids
        else
          # If no active accounts stored yet, use all for unlimited or go to account selection
          if existing_subscription.plan.unlimited?
            session[:selected_customer_ids] = customer_ids
          else
            # Let them select accounts again within their plan limits
            redirect_to google_ads_select_plan_path, notice: "Reconectado! Por favor, confirme as contas ativas do seu plano."
            return
          end
        end

        redirect_to google_ads_select_account_path, notice: "Reconectado! Selecione a conta principal para continuar."
      else
        # No active subscription - go to plan selection
        redirect_to google_ads_select_plan_path, notice: "Encontramos #{customer_ids.count} conta(s) acessível(is). Por favor, escolha um plano para continuar."
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

    def select_plan
      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]

      unless google_account_id && customer_ids
        redirect_to dashboard_path, alert: "Sessão expirada. Por favor, tente conectar novamente."
        return
      end

      @google_account = current_user.google_accounts.find(google_account_id)
      @customer_ids = customer_ids
      @accounts_count = customer_ids.count

      # Fetch available plans (new sub-account based plans)
      @plans = Plan.active.ordered

      # Fetch customer names for display
      @customer_names = fetch_customer_names(@google_account, customer_ids)
    end

    def save_plan_selection
      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]
      plan_id = params[:plan_id]
      selected_ids = params[:selected_customer_ids] || []

      # Ensure selected_ids is an array
      selected_ids = [ selected_ids ] unless selected_ids.is_a?(Array)
      selected_ids = selected_ids.reject(&:blank?)

      unless google_account_id && customer_ids && plan_id.present?
        redirect_to dashboard_path, alert: "Parâmetros inválidos."
        return
      end

      plan = Plan.active.find(plan_id)
      google_account = current_user.google_accounts.find(google_account_id)

      # Validate selection
      if selected_ids.empty?
        redirect_to google_ads_select_plan_path, alert: "Selecione pelo menos uma conta para ativar."
        return
      end

      # Check plan limits
      if plan.max_accounts && selected_ids.count > plan.max_accounts
        redirect_to google_ads_select_plan_path, alert: "Este plano permite no máximo #{plan.max_accounts} contas. Você selecionou #{selected_ids.count}."
        return
      end

      # Store plan and selected accounts in session
      session[:selected_plan_id] = plan.id
      session[:selected_customer_ids] = selected_ids

      # Create or update user subscription as pending
      subscription = current_user.user_subscription || current_user.build_user_subscription
      subscription.plan = plan
      subscription.selected_accounts_count = selected_ids.count
      subscription.status = "pending"
      subscription.save!

      # Mark selected accounts as active, others as inactive
      customer_ids.each do |cid|
        ac = google_account.accessible_customers.find_or_create_by(customer_id: cid)
        ac.update!(active: selected_ids.include?(cid))
      end

      # Redirect to Stripe Payment Link for payment
      if plan.stripe_payment_link.present?
        payment_url = plan.payment_link_url_for(current_user)
        redirect_to payment_url, allow_other_host: true
      else
        # No payment link configured - activate directly (dev mode)
        subscription.update!(status: "active", started_at: Time.current)
        current_user.update!(allowed: true)
        redirect_to google_ads_select_account_path, notice: "Plano ativado! Agora escolha qual será sua conta principal."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to google_ads_select_plan_path, alert: "Plano não encontrado."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to google_ads_select_plan_path, alert: "Erro ao salvar: #{e.message}"
    end

    def select_active_accounts
      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]
      plan_id = session[:selected_plan_id]

      unless google_account_id && customer_ids && plan_id
        redirect_to dashboard_path, alert: "Sessão expirada. Por favor, tente conectar novamente."
        return
      end

      @google_account = current_user.google_accounts.find(google_account_id)
      @customer_ids = customer_ids
      @plan = Plan.find(plan_id)

      # Calculate max accounts allowed
      @max_accounts = @plan.max_accounts || customer_ids.count

      # For per_account plan, no limit but price increases
      @is_per_account = @plan.per_account?
      @price_per_account = @plan.price_per_account_brl if @is_per_account

      # Fetch customer names for display
      @customer_names = fetch_customer_names(@google_account, customer_ids)
    end

    def save_active_accounts
      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]
      plan_id = session[:selected_plan_id]
      selected_ids = params[:selected_customer_ids] || []

      # Ensure selected_ids is an array
      selected_ids = [ selected_ids ] unless selected_ids.is_a?(Array)
      selected_ids = selected_ids.reject(&:blank?)

      unless google_account_id && customer_ids && plan_id
        redirect_to dashboard_path, alert: "Sessão expirada. Por favor, tente conectar novamente."
        return
      end

      plan = Plan.find(plan_id)

      # Validate selection
      if selected_ids.empty?
        redirect_to google_ads_select_active_accounts_path, alert: "Selecione pelo menos uma conta para ativar."
        return
      end

      # Check plan limits
      if plan.max_accounts && selected_ids.count > plan.max_accounts
        redirect_to google_ads_select_active_accounts_path, alert: "Este plano permite no máximo #{plan.max_accounts} contas. Você selecionou #{selected_ids.count}."
        return
      end

      # Store selected accounts and create/update subscription
      session[:selected_customer_ids] = selected_ids

      # Create or update user subscription with selected accounts count
      subscription = current_user.user_subscription || current_user.build_user_subscription
      subscription.plan = plan
      subscription.selected_accounts_count = selected_ids.count
      subscription.status = "pending"
      subscription.save!

      redirect_to google_ads_select_account_path, notice: "#{selected_ids.count} conta(s) selecionada(s)! Agora escolha qual será sua conta principal."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to google_ads_select_active_accounts_path, alert: "Erro ao salvar: #{e.message}"
    end

    def select_account
      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]
      selected_customer_ids = session[:selected_customer_ids]

      unless google_account_id && customer_ids
        redirect_to dashboard_path, alert: "Sessão expirada. Por favor, tente conectar novamente."
        return
      end

      # Check if plan was selected (skip for allowed users)
      unless session[:selected_plan_id].present? || current_user.allowed?
        redirect_to google_ads_select_plan_path, alert: "Por favor, selecione um plano primeiro."
        return
      end

      @google_account = current_user.google_accounts.find(google_account_id)
      @selected_plan = session[:selected_plan_id] ? Plan.find(session[:selected_plan_id]) : nil

      # For unlimited plan with no max, all accounts are selectable
      if @selected_plan&.unlimited? || current_user.allowed?
        @customer_ids = customer_ids
        @active_customer_ids = customer_ids
      else
        # Only show selected/active accounts for selection
        @customer_ids = selected_customer_ids || customer_ids
        @active_customer_ids = selected_customer_ids || []
      end

      @selected_accounts_count = @active_customer_ids.count

      # Fetch customer names in parallel for performance
      @customer_names = fetch_customer_names(@google_account, customer_ids)
    end

    def save_account_selection
      google_account_id = params[:google_account_id]
      selected_customer_id = params[:login_customer_id]
      customer_names_json = params[:customer_names]
      selected_customer_ids = session[:selected_customer_ids] || session[:accessible_customer_ids]

      unless google_account_id.present? && selected_customer_id.present?
        redirect_to dashboard_path, alert: "Parâmetros inválidos."
        return
      end

      google_account = current_user.google_accounts.find(google_account_id)
      plan = Plan.find(session[:selected_plan_id]) if session[:selected_plan_id]

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

      # ⚠️ IMPORTANTE: manager_customer_id é a conta RAIZ (root manager account)
      # Deve ser definido UMA VEZ e nunca alterado
      # login_customer_id é usado para requisições e pode ser a mesma coisa
      unless google_account.manager_customer_id.present?
        google_account.update!(manager_customer_id: selected_customer_id)
        Rails.logger.info("[GoogleAds::ConnectionsController] Set manager_customer_id to #{selected_customer_id} (root manager account)")
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

      Rails.logger.info("[GoogleAds::ConnectionsController] Created/updated ActiveCustomerSelection: customer_id=#{selection.customer_id}, google_account_id=#{selection.google_account_id}, id=#{selection.id}")

      session[:active_customer_id] = selection.customer_id
      session[:active_google_account_id] = selection.google_account_id

      # Try to fetch accessible customers and save them with names and active status
      begin
        service = GoogleAds::CustomerService.new(google_account: google_account)
        fetched_customer_ids = service.list_accessible_customers

        Rails.logger.info("[GoogleAds::ConnectionsController] Creating #{fetched_customer_ids.count} AccessibleCustomer records")

        # Determine which accounts should be active
        active_ids = if plan&.unlimited? || current_user.allowed?
          fetched_customer_ids # All active for unlimited plan or allowed users
        else
          selected_customer_ids || []
        end

        # Create AccessibleCustomer records with names from form and active status
        fetched_customer_ids.each do |customer_id|
          display_name = customer_names[customer_id]
          accessible_customer = google_account.accessible_customers.find_or_create_by(customer_id: customer_id)

          # Set active status based on selection
          is_active = active_ids.include?(customer_id)
          accessible_customer.active = is_active

          if display_name.present? && accessible_customer.display_name.blank?
            accessible_customer.display_name = display_name
          end

          accessible_customer.save!

          if is_active
            Rails.logger.info("[GoogleAds::ConnectionsController] ✅ Activated account #{customer_id}: #{display_name}")
          else
            Rails.logger.info("[GoogleAds::ConnectionsController] ⚪ Inactive account #{customer_id}: #{display_name}")
          end
        end

      rescue => e
        Rails.logger.warn("[GoogleAds::ConnectionsController] Could not fetch accessible customers: #{e.message}")
      end

      # Log activity
      ActivityLogger.log_account_connected(
        user: current_user,
        login_customer_id: google_account.login_customer_id || selected_customer_id,
        request: request
      )

      # Check subscription status
      subscription = current_user.user_subscription

      # If user is allowed or subscription is already active, go directly to dashboard
      if current_user.allowed? || subscription&.active?
        # Clear session data
        clear_plan_session_data

        redirect_to leads_path, notice: "Conta Google Ads conectada com sucesso!"
        return
      end

      # Pending subscription - should not normally reach here since payment happens before
      # But handle it gracefully
      if subscription&.pending? && subscription.plan.present?
        clear_plan_session_data
        redirect_to leads_path, notice: "Conta conectada! Aguardando confirmação do pagamento."
      else
        redirect_to google_ads_select_plan_path, alert: "Por favor, selecione um plano para continuar."
      end
    end

    def change_plan
      @current_subscription = current_user.user_subscription
      unless @current_subscription
        redirect_to google_ads_select_plan_path, alert: "Você ainda não tem um plano. Por favor, selecione um."
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

      # Update active status on accessible_customers
      google_account = current_user.google_accounts.first
      if google_account
        google_account.accessible_customers.each do |ac|
          is_active = selected_ids.include?(ac.customer_id)
          ac.update!(active: is_active)
        end
      end

      # Redirect to Stripe Payment Link for payment
      if plan.stripe_payment_link.present?
        payment_url = plan.payment_link_url_for(current_user)
        redirect_to payment_url, allow_other_host: true
      else
        # No payment link configured - activate directly (dev mode)
        subscription.update!(status: "active", started_at: Time.current)
        current_user.update!(allowed: true)
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
      # Permite trocar de customer_id sem alterar login_customer_id
      google_account_id = params[:google_account_id]
      new_customer_id = params[:customer_id]

      unless google_account_id.present? && new_customer_id.present?
        return render json: { error: "Parâmetros inválidos" }, status: :bad_request
      end

      google_account = current_user.google_accounts.find(google_account_id)

      # Verifica se o customer_id é acessível
      accessible = google_account.accessible_customers.find_by(customer_id: new_customer_id)
      unless accessible
        return render json: { error: "Conta não acessível" }, status: :forbidden
      end

      # Atualiza a seleção ativa
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

    helper_method :format_customer_id

    def format_customer_id(customer_id)
      return "N/A" unless customer_id.present?

      # Format customer_id: 9604421505 -> 960-442-1505
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
            # Each customer can only be queried using its own ID as login_customer_id
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

      # Wait for all threads to complete
      threads.each(&:join)

      Rails.logger.info("[GoogleAds::ConnectionsController] Successfully fetched #{customer_names.count} names out of #{customer_ids.count}")

      customer_names
    end
  end
end
