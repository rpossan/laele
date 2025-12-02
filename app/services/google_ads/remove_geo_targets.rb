module GoogleAds
  class RemoveGeoTargets
    def initialize(google_account:, customer_id:)
      @google_account = google_account
      @customer_id = customer_id
      @client = ClientBuilder.new(google_account: google_account).build
      @service = @client.service.campaign_criterion
    end

    def remove_targets(resource_names)
      return [] if resource_names.empty?

      # Use REST API for mutations (more reliable than gRPC for mutations)
      remove_targets_via_rest(resource_names)
    end

    private

    def remove_targets_via_rest(resource_names)
      require "net/http"
      require "uri"
      require "json"
      require "signet/oauth_2/client"

      # Get access token
      oauth_client = Signet::OAuth2::Client.new(
        client_id: ENV["GOOGLE_ADS_CLIENT_ID"],
        client_secret: ENV["GOOGLE_ADS_CLIENT_SECRET"],
        token_credential_uri: "https://oauth2.googleapis.com/token",
        refresh_token: @google_account.refresh_token
      )
      
      oauth_client.refresh!
      access_token = oauth_client.access_token

      unless access_token
        raise "Falha ao obter access token"
      end

      # Build operations
      operations = resource_names.map do |resource_name|
        {
          "remove" => resource_name
        }
      end

      # Make REST API call
      uri = URI("https://googleads.googleapis.com/v22/customers/#{@customer_id}/campaignCriteria:mutate")
      
      request_body = {
        "operations" => operations
      }
      
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      
      if @google_account.login_customer_id.present?
        req["login-customer-id"] = @google_account.login_customer_id
      end
      
      req.body = request_body.to_json

      Rails.logger.info("[GoogleAds::RemoveGeoTargets] Removing #{operations.size} location targets")
      Rails.logger.debug("[GoogleAds::RemoveGeoTargets] Request body: #{request_body.to_json}")

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      unless res.code.to_i == 200
        error_body = res.body.force_encoding("UTF-8") rescue res.body
        Rails.logger.error("[GoogleAds::RemoveGeoTargets] REST API error: #{res.code}")
        Rails.logger.error("[GoogleAds::RemoveGeoTargets] Response body: #{error_body[0..500]}")
        raise "Google Ads API error: #{res.code} - #{error_body[0..200]}"
      end

      data = JSON.parse(res.body)
      results = data["results"] || []
      removed_resource_names = results.map { |r| r["resourceName"] }.compact

      Rails.logger.info("[GoogleAds::RemoveGeoTargets] Successfully removed #{removed_resource_names.size} location targets")
      
      removed_resource_names
    end

    private

    attr_reader :google_account, :customer_id, :client
  end
end

