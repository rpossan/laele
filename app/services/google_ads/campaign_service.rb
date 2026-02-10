require "net/http"
require "uri"
require "json"
require "signet/oauth_2/client"

module GoogleAds
  class CampaignService
    def initialize(google_account:, customer_id:)
      @google_account = google_account
      @customer_id = customer_id
      client = ClientBuilder.new(google_account: google_account).build
      @service = client.service.google_ads
    end

    def list_campaigns
      query = <<~GAQL
        SELECT
          campaign.id,
          campaign.name,
          campaign.status,
          campaign.advertising_channel_type
        FROM campaign
        WHERE campaign.advertising_channel_type = LOCAL_SERVICES
        ORDER BY campaign.name
      GAQL

      Rails.logger.info("[GoogleAds::CampaignService] Fetching LSA campaigns for customer #{@customer_id}")
      Rails.logger.debug("[GoogleAds::CampaignService] Query: #{query}")

      # Try REST API first (more reliable)
      begin
        result = list_campaigns_via_rest(query)
        return result if result
      rescue => e
        Rails.logger.warn("[GoogleAds::CampaignService] REST API failed, trying gRPC: #{e.message}")
      end

      # Fallback to gRPC
      begin
        response_enum = @service.search_stream(
          customer_id: @customer_id,
          query: query
        )

        campaigns = []
        response_enum.each do |response|
          if response.respond_to?(:results) && response.results
            response.results.each do |row|
              campaign = row.campaign
              campaigns << {
                id: campaign.id.to_s,
                name: campaign.name,
                status: campaign.status.to_s,
                advertising_channel_type: campaign.advertising_channel_type.to_s
              }
            end
          end
        end

        Rails.logger.info("[GoogleAds::CampaignService] Found #{campaigns.size} LSA campaigns")
        campaigns
      rescue GRPC::Unimplemented => e
        Rails.logger.warn("[GoogleAds::CampaignService] gRPC not available: #{e.message}")
        []
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        Rails.logger.error("[GoogleAds::CampaignService] GoogleAdsError: #{e.class}")
        Rails.logger.error("[GoogleAds::CampaignService] Message: #{e.message}")
        raise e
      rescue => e
        Rails.logger.error("[GoogleAds::CampaignService] Unexpected error: #{e.class} - #{e.message}")
        raise e
      end
    end

    private

    attr_reader :google_account, :customer_id

    def list_campaigns_via_rest(query)
      Rails.logger.info("[GoogleAds::CampaignService] Starting REST API request for campaigns")

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
        Rails.logger.error("[GoogleAds::CampaignService] Failed to obtain access token")
        return nil
      end

      Rails.logger.debug("[GoogleAds::CampaignService] Access token obtained successfully")

      uri = URI("https://googleads.googleapis.com/v22/customers/#{@customer_id}/googleAds:search")

      Rails.logger.info("[GoogleAds::CampaignService] Request URL: #{uri}")
      Rails.logger.info("[GoogleAds::CampaignService] Request method: POST")
      Rails.logger.info("[GoogleAds::CampaignService] Customer ID: #{@customer_id}")
      
      # ⚠️ IMPORTANTE: login-customer-id deve ser o próprio customer_id
      # Cada customer só pode ser consultado usando seu próprio ID como login_customer_id
      login_customer_id_to_use = @customer_id
      Rails.logger.info("[GoogleAds::CampaignService] Login Customer ID: #{login_customer_id_to_use}")

      request_body = { query: query }

      Rails.logger.debug("[GoogleAds::CampaignService] Request body: #{request_body.to_json}")

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"

      if login_customer_id_to_use.present?
        req["login-customer-id"] = login_customer_id_to_use
        Rails.logger.debug("[GoogleAds::CampaignService] Added login-customer-id header: #{login_customer_id_to_use}")
      end

      req.body = request_body.to_json

      Rails.logger.info("[GoogleAds::CampaignService] Sending request to Google Ads API...")
      start_time = Time.now

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      elapsed_time = ((Time.now - start_time) * 1000).round(2)
      Rails.logger.info("[GoogleAds::CampaignService] Response received in #{elapsed_time}ms")
      Rails.logger.info("[GoogleAds::CampaignService] Response status: #{res.code}")
      Rails.logger.debug("[GoogleAds::CampaignService] Response headers: #{res.to_hash.inspect}")

      unless res.code.to_i == 200
        error_body = res.body.force_encoding("UTF-8") rescue res.body
        Rails.logger.error("[GoogleAds::CampaignService] REST API error: #{res.code}")
        Rails.logger.error("[GoogleAds::CampaignService] Response body: #{error_body[0..500]}")
        return nil
      end

      Rails.logger.debug("[GoogleAds::CampaignService] Response body size: #{res.body.bytesize} bytes")

      data = JSON.parse(res.body)
      results = data["results"] || []

      Rails.logger.info("[GoogleAds::CampaignService] Parsed #{results.size} results from response")

      campaigns = results.map do |result|
        campaign = result["campaign"] || result["campaign"]
        next unless campaign

        {
          id: campaign["id"].to_s,
          name: campaign["name"] || "",
          status: campaign["status"] || "",
          advertising_channel_type: campaign["advertisingChannelType"] || campaign["advertising_channel_type"] || ""
        }
      end.compact

      Rails.logger.info("[GoogleAds::CampaignService] Found #{campaigns.size} LSA campaigns via REST API")
      Rails.logger.debug("[GoogleAds::CampaignService] Campaign IDs: #{campaigns.map { |c| c[:id] }.join(', ')}")
      campaigns
    end
  end
end
