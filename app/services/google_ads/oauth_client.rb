require "signet/oauth_2/client"

module GoogleAds
  class OauthClient
    include Rails.application.routes.url_helpers

    SCOPE = "https://www.googleapis.com/auth/adwords".freeze

    def initialize(redirect_uri: nil)
      @redirect_uri = redirect_uri.presence || default_redirect_uri
    end

    def authorization_url(state:)
      client = build_client(access_type: "offline", prompt: "consent")
      client.state = state
      client.authorization_uri.to_s
    end

    def exchange_code(code)
      client = build_client
      client.code = code
      response = client.fetch_access_token!
      
      # Log for debugging - check both client and response
      Rails.logger.info("[GoogleAds::OauthClient] Token exchange successful.")
      Rails.logger.info("[GoogleAds::OauthClient] Client refresh_token present: #{client.refresh_token.present?}")
      Rails.logger.info("[GoogleAds::OauthClient] Response keys: #{response.keys.inspect}") if response.is_a?(Hash)
      Rails.logger.info("[GoogleAds::OauthClient] Response has refresh_token: #{response['refresh_token'].present?}") if response.is_a?(Hash)
      
      # If refresh_token is in response but not in client, set it manually
      if response.is_a?(Hash) && response['refresh_token'].present? && client.refresh_token.blank?
        client.refresh_token = response['refresh_token']
        Rails.logger.info("[GoogleAds::OauthClient] Manually set refresh_token from response")
      end
      
      client
    rescue Signet::AuthorizationError => e
      Rails.logger.error("[GoogleAds::OauthClient] Token exchange failed: #{e.message}")
      raise
    end

    private

    attr_reader :redirect_uri

    def build_client(access_type: nil, prompt: nil)
      Signet::OAuth2::Client.new(
        client_id: ENV.fetch("GOOGLE_ADS_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_ADS_CLIENT_SECRET"),
        authorization_uri: "https://accounts.google.com/o/oauth2/v2/auth",
        token_credential_uri: "https://oauth2.googleapis.com/token",
        redirect_uri: redirect_uri,
        scope: SCOPE,
        additional_parameters: build_additional_parameters(access_type:, prompt:)
      )
    end

    def build_additional_parameters(access_type:, prompt:)
      params = {}
      params[:access_type] = access_type if access_type
      params[:prompt] = prompt if prompt
      params[:include_granted_scopes] = "true"
      params
    end

    def default_redirect_uri
      ENV["GOOGLE_ADS_REDIRECT_URI"]
    end
  end
end

