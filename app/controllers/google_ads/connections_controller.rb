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

      google_account = @user.google_accounts.find_or_initialize_by(login_customer_id:)
      google_account.login_customer_id ||= login_customer_id
      google_account.refresh_token = token_client.refresh_token if token_client.refresh_token.present?
      google_account.scopes = token_client.scope.to_s.split(" ")
      google_account.save!

      GoogleAds::CustomerService.new(google_account:).list_accessible_customers

      redirect_to dashboard_path, notice: "Conta Google Ads conectada com sucesso."
    rescue Signet::AuthorizationError => e
      redirect_to dashboard_path, alert: "Falha ao trocar o código por token: #{e.message}"
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      redirect_to dashboard_path, alert: "Google Ads API retornou erro: #{e.message}"
    end

    def destroy
      @google_account.destroy!
      redirect_to dashboard_path, notice: "Conexão removida."
    end

    private

    def set_google_account
      @google_account = current_user.google_accounts.find(params[:id])
    end
  end
end

