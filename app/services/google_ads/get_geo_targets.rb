module GoogleAds
  class GetGeoTargets
    def initialize(google_account:, customer_id:, campaign_id:)
      @google_account = google_account
      @customer_id = customer_id
      @campaign_id = campaign_id
      client = ClientBuilder.new(google_account: google_account).build
      @service = client.service.google_ads
    end

    def fetch_existing_targets
      query = <<~GAQL
        SELECT
          campaign_criterion.resource_name,
          campaign_criterion.location.geo_target_constant
        FROM campaign_criterion
        WHERE
          campaign_criterion.campaign = 'customers/#{@customer_id}/campaigns/#{@campaign_id}'
          AND campaign_criterion.type = LOCATION
      GAQL

      Rails.logger.info("[GoogleAds::GetGeoTargets] Fetching existing geo targets for campaign #{@campaign_id}")
      Rails.logger.debug("[GoogleAds::GetGeoTargets] Query: #{query}")

      # Try REST API first (more reliable)
      begin
        result = fetch_existing_targets_via_rest(query)
        return result if result
      rescue => e
        Rails.logger.warn("[GoogleAds::GetGeoTargets] REST API failed, trying gRPC: #{e.message}")
      end

      # Fallback to gRPC
      begin
        response_enum = @service.search_stream(
          customer_id: @customer_id,
          query: query
        )

        results = []
        response_enum.each do |response|
          if response.respond_to?(:results) && response.results
            response.results.each do |row|
              criterion = row.campaign_criterion
              if criterion.location&.geo_target_constant
                results << {
                  resource_name: criterion.resource_name,
                  geo_target_constant: criterion.location.geo_target_constant
                }
              end
            end
          end
        end

        Rails.logger.info("[GoogleAds::GetGeoTargets] Found #{results.size} existing geo targets")
        results
      rescue GRPC::Unimplemented => e
        Rails.logger.warn("[GoogleAds::GetGeoTargets] gRPC not available: #{e.message}")
        []
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        Rails.logger.error("[GoogleAds::GetGeoTargets] GoogleAdsError: #{e.class}")
        Rails.logger.error("[GoogleAds::GetGeoTargets] Message: #{e.message}")
        
        if e.respond_to?(:failure) && e.failure
          e.failure.errors.each do |error|
            Rails.logger.error("[GoogleAds::GetGeoTargets] Error code: #{error.error_code}")
            Rails.logger.error("[GoogleAds::GetGeoTargets] Error message: #{error.message}")
          end
        end
        
        raise e
      rescue => e
        Rails.logger.error("[GoogleAds::GetGeoTargets] Unexpected error: #{e.class} - #{e.message}")
        Rails.logger.error("[GoogleAds::GetGeoTargets] Backtrace: #{e.backtrace.first(10).join("\n")}")
        raise e
      end
    end

    private

    def fetch_existing_targets_via_rest(query)
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

      return nil unless access_token

      uri = URI("https://googleads.googleapis.com/v22/customers/#{@customer_id}/googleAds:search")
      
      request_body = { query: query }
      
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      
      # ⚠️ IMPORTANTE: login-customer-id deve ser o próprio customer_id
      # Cada customer só pode ser consultado usando seu próprio ID como login_customer_id
      if @customer_id.present?
        req["login-customer-id"] = @customer_id
      end
      
      req.body = request_body.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      return nil unless res.code.to_i == 200

      data = JSON.parse(res.body)
      results = data["results"] || []
      
      formatted_results = results.map do |result|
        criterion = result["campaignCriterion"] || result["campaign_criterion"]
        next unless criterion
        
        location = criterion["location"]
        next unless location && location["geoTargetConstant"]
        
        {
          resource_name: criterion["resourceName"] || criterion["resource_name"],
          geo_target_constant: location["geoTargetConstant"] || location["geo_target_constant"]
        }
      end.compact

      Rails.logger.info("[GoogleAds::GetGeoTargets] Found #{formatted_results.size} existing geo targets via REST API")
      formatted_results
    end

    private

    attr_reader :google_account, :customer_id, :campaign_id
  end
end

