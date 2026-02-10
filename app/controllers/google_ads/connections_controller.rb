require "ostruct"

module GoogleAds
  class ConnectionsController < ApplicationController
    before_action :authenticate_user!, except: [:callback]
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

      # Store customer_ids in session and redirect to selection page
      session[:pending_google_account_id] = google_account.id
      session[:accessible_customer_ids] = customer_ids

      redirect_to google_ads_select_account_path, notice: "Encontramos #{customer_ids.count} conta(s) acessível(is). Por favor, escolha qual conta deseja usar."
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

    def select_account
      google_account_id = session[:pending_google_account_id]
      customer_ids = session[:accessible_customer_ids]

      unless google_account_id && customer_ids
        redirect_to dashboard_path, alert: "Sessão expirada. Por favor, tente conectar novamente."
        return
      end

      @google_account = current_user.google_accounts.find(google_account_id)
      @customer_ids = customer_ids
      
      # Fetch customer names in parallel for performance
      @customer_names = {}
      
      if customer_ids.any?
        Rails.logger.info("[GoogleAds::ConnectionsController] Fetching names for #{customer_ids.count} customers in parallel")
        
        threads = []
        mutex = Mutex.new
        
        customer_ids.each do |customer_id|
          threads << Thread.new(customer_id) do |cid|
            begin
              # Each customer can only be queried using its own ID as login_customer_id
              temp_account = OpenStruct.new(
                refresh_token: @google_account.refresh_token,
                login_customer_id: cid
              )
              
              temp_service = GoogleAds::CustomerService.new(google_account: temp_account)
              details = temp_service.fetch_customer_details(cid)
              
              if details && details[:descriptive_name].present?
                mutex.synchronize do
                  @customer_names[cid] = details[:descriptive_name]
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
        
        Rails.logger.info("[GoogleAds::ConnectionsController] Successfully fetched #{@customer_names.count} names out of #{customer_ids.count}")
      end
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
      
      # Parse customer names from form
      customer_names = {}
      begin
        customer_names = JSON.parse(customer_names_json) if customer_names_json.present?
      rescue => e
        Rails.logger.warn("[GoogleAds::ConnectionsController] Failed to parse customer_names: #{e.message}")
      end
      
      # ⚠️ IMPORTANTE: manager_customer_id é a conta RAIZ (root manager account)
      # Deve ser definido UMA VEZ e nunca alterado
      # login_customer_id é usado para requisições e pode ser a mesma coisa
      unless google_account.manager_customer_id.present?
        google_account.update!(
          manager_customer_id: selected_customer_id,
          login_customer_id: selected_customer_id
        )
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

      # Try to fetch accessible customers and save them with names
      begin
        service = GoogleAds::CustomerService.new(google_account: google_account)
        fetched_customer_ids = service.list_accessible_customers
        
        Rails.logger.info("[GoogleAds::ConnectionsController] Creating #{fetched_customer_ids.count} AccessibleCustomer records")
        
        # Create AccessibleCustomer records with names from form
        fetched_customer_ids.each do |customer_id|
          display_name = customer_names[customer_id]
          accessible_customer = google_account.accessible_customers.find_or_create_by(customer_id: customer_id)
          
          if display_name.present? && accessible_customer.display_name.blank?
            accessible_customer.update(display_name: display_name)
            Rails.logger.info("[GoogleAds::ConnectionsController] ✅ Saved name for #{customer_id}: #{display_name}")
          elsif display_name.blank?
            Rails.logger.warn("[GoogleAds::ConnectionsController] No name available for #{customer_id}")
          end
        end
        
      rescue => e
        Rails.logger.warn("[GoogleAds::ConnectionsController] Could not fetch accessible customers: #{e.message}")
      end

      # Clear session data
      session.delete(:pending_google_account_id)
      session.delete(:accessible_customer_ids)

      # Log activity
      ActivityLogger.log_account_connected(
        user: current_user,
        login_customer_id: google_account.login_customer_id || selected_customer_id,
        request: request
      )

      redirect_to leads_path, notice: "Conta Google Ads conectada com sucesso!"
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
  end
end

