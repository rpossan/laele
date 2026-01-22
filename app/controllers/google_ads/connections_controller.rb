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
      
      # Fetch customer names for display using batch request for better performance
      @customer_names = {}
      
      if customer_ids.any?
        begin
          # Try batch request first - much faster than individual requests
          temp_account = OpenStruct.new(
            refresh_token: @google_account.refresh_token,
            login_customer_id: @google_account.login_customer_id
          )
          
          temp_service = GoogleAds::CustomerService.new(google_account: temp_account)
          batch_results = temp_service.fetch_multiple_customer_details(customer_ids)
          
          if batch_results.any?
            @customer_names = batch_results
            Rails.logger.info("[GoogleAds::ConnectionsController] ✅ Batch fetched #{batch_results.count} customer names")
          else
            Rails.logger.warn("[GoogleAds::ConnectionsController] ⚠️ Batch request returned no results, falling back to individual requests")
            # The service will automatically fall back to individual requests
          end
        rescue => e
          Rails.logger.warn("[GoogleAds::ConnectionsController] ⚠️ Batch request failed: #{e.message}")
          # Fallback to individual requests (the old way)
          customer_ids.each do |customer_id|
            begin
              temp_account = OpenStruct.new(
                refresh_token: @google_account.refresh_token,
                login_customer_id: customer_id
              )
              
              temp_service = GoogleAds::CustomerService.new(google_account: temp_account)
              details = temp_service.fetch_customer_details(customer_id)
              
              if details && details[:descriptive_name].present?
                @customer_names[customer_id] = details[:descriptive_name]
                Rails.logger.info("[GoogleAds::ConnectionsController] ✅ Individual fetch for #{customer_id}: #{details[:descriptive_name]}")
              end
            rescue => e
              Rails.logger.warn("[GoogleAds::ConnectionsController] ⚠️ Could not fetch name for #{customer_id}: #{e.message}")
            end
          end
        end
      end
    end

    def save_account_selection
      google_account_id = params[:google_account_id]
      selected_customer_id = params[:login_customer_id]

      unless google_account_id.present? && selected_customer_id.present?
        redirect_to dashboard_path, alert: "Parâmetros inválidos."
        return
      end

      google_account = current_user.google_accounts.find(google_account_id)
      
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

      # Try to fetch accessible customers (but don't fetch names for all - too slow and may have permission issues)
      begin
        service = GoogleAds::CustomerService.new(google_account: google_account)
        customer_ids = service.list_accessible_customers
        
        # Create AccessibleCustomer records (without fetching names for all)
        customer_ids.each do |customer_id|
          google_account.accessible_customers.find_or_create_by(customer_id: customer_id)
        end
        
        # Only fetch the name for the SELECTED account
        begin
          # Create a temporary google_account with the selected customer_id as login_customer_id
          # This allows us to query the account directly without permission issues
          temp_account = OpenStruct.new(
            refresh_token: google_account.refresh_token,
            login_customer_id: selected_customer_id
          )
          
          temp_service = GoogleAds::CustomerService.new(google_account: temp_account)
          details = temp_service.fetch_customer_details(selected_customer_id)
          
          if details && details[:descriptive_name].present?
            accessible_customer = google_account.accessible_customers.find_by(customer_id: selected_customer_id)
            if accessible_customer
              accessible_customer.update(display_name: details[:descriptive_name])
              Rails.logger.info("[GoogleAds::ConnectionsController] ✅ Fetched name for selected account #{selected_customer_id}: #{details[:descriptive_name]}")
            end
          end
        rescue => e
          Rails.logger.warn("[GoogleAds::ConnectionsController] Could not fetch name for selected account #{selected_customer_id}: #{e.message}")
        end
      rescue => e
        Rails.logger.warn("[GoogleAds::ConnectionsController] Could not fetch accessible customers: #{e.message}")
        # Don't fail the whole process if we can't fetch accessible customers
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

      redirect_to dashboard_path, notice: "Conta Google Ads conectada com sucesso!"
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

