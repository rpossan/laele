require "net/http"
require "uri"
require "json"
require "ostruct"

module GoogleAds
  class CustomerService
    def initialize(google_account:)
      @google_account = google_account
    end

    def list_accessible_customers
      # ❗ Google Ads API v22 does NOT expose listAccessibleCustomers via gRPC.
      # Use REST endpoint instead, but the endpoint might not be publicly documented.
      # Alternative: Use the gem's internal HTTP client or try different endpoint formats
      
      begin
        # Exchange refresh_token → access_token using Signet (same as OAuthClient)
        require "signet/oauth_2/client"
        
        oauth_client = Signet::OAuth2::Client.new(
          client_id: ENV["GOOGLE_ADS_CLIENT_ID"],
          client_secret: ENV["GOOGLE_ADS_CLIENT_SECRET"],
          token_credential_uri: "https://oauth2.googleapis.com/token",
          refresh_token: @google_account.refresh_token
        )
        
        oauth_client.refresh!
        access_token = oauth_client.access_token

        unless access_token
          Rails.logger.error("[GoogleAds::CustomerService] Failed to get access token")
          raise "Falha ao obter access token"
        end

        # Try different endpoint formats
        endpoints_to_try = [
          "https://googleads.googleapis.com/v22/customers:listAccessibleCustomers",
          "https://googleads.googleapis.com/v17/customers:listAccessibleCustomers",
          "https://googleads.googleapis.com/v22/customers/listAccessibleCustomers",
          "https://googleads.googleapis.com/v17/customers/listAccessibleCustomers"
        ]

        last_error = nil
        endpoints_to_try.each do |endpoint_url|
          begin
            uri = URI(endpoint_url)
            req = Net::HTTP::Get.new(uri)
            req["Authorization"] = "Bearer #{access_token}"
            req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
            req["Content-Type"] = "application/json"

            res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

            if res.code.to_i == 200
              data = JSON.parse(res.body)
              if data["resourceNames"]
                customer_ids = data["resourceNames"].map { |r| r.split("/").last }
                Rails.logger.info("[GoogleAds::CustomerService] Found #{customer_ids.count} accessible customers using #{endpoint_url}")
                return customer_ids
              end
            elsif res.code.to_i != 404
              # If it's not 404, log it but continue trying
              Rails.logger.warn("[GoogleAds::CustomerService] Endpoint #{endpoint_url} returned #{res.code}")
              last_error = "HTTP #{res.code}"
            end
          rescue => e
            Rails.logger.warn("[GoogleAds::CustomerService] Error trying #{endpoint_url}: #{e.message}")
            last_error = e.message
          end
        end

        # If all REST endpoints fail, raise an error suggesting manual entry
        raise "Não foi possível listar contas acessíveis automaticamente. Os endpoints REST não estão disponíveis. Por favor, insira o customer_id manualmente."
      rescue JSON::ParserError => e
        Rails.logger.error("[GoogleAds::CustomerService] JSON parse error: #{e.message}")
        raise "Erro ao processar resposta JSON: #{e.message}"
      rescue => e
        Rails.logger.error("[GoogleAds::CustomerService] Error: #{e.class} - #{e.message}")
        Rails.logger.error("[GoogleAds::CustomerService] Backtrace: #{e.backtrace.first(10).join("\n")}")
        raise "Erro ao listar contas acessíveis: #{e.message}"
      end
    end

    def fetch_customer_details(customer_id)
      query = <<~GAQL
        SELECT
          customer.id,
          customer.descriptive_name
        FROM customer
      GAQL

      Rails.logger.info("[GoogleAds::CustomerService] Fetching customer details for #{customer_id}")

      # Try REST API first (more reliable)
      begin
        result = fetch_customer_details_via_rest(customer_id, query)
        return result if result && result[:descriptive_name].present?
      rescue => e
        Rails.logger.warn("[GoogleAds::CustomerService] REST API failed, trying gRPC: #{e.message}")
      end

      # Fallback to gRPC
      begin
        client = GoogleAds::ClientBuilder.new(google_account: @google_account).build
        
        response = client.service.google_ads.search_stream(
          customer_id: customer_id,
          query: query
        )

        customer_data = nil
        response.each do |row|
          customer_data = row.customer
          break
        end

        if customer_data && customer_data.descriptive_name.present?
          {
            id: customer_data.id.to_s,
            descriptive_name: customer_data.descriptive_name
          }
        else
          Rails.logger.warn("[GoogleAds::CustomerService] No customer data found for #{customer_id}")
          { id: customer_id, descriptive_name: nil }
        end
      rescue GRPC::Unimplemented => e
        Rails.logger.warn("[GoogleAds::CustomerService] gRPC not available: #{e.message}")
        { id: customer_id, descriptive_name: nil }
      rescue => e
        Rails.logger.error("[GoogleAds::CustomerService] Error fetching customer details for #{customer_id}: #{e.message}")
        Rails.logger.error("[GoogleAds::CustomerService] Backtrace: #{e.backtrace.first(5).join("\n")}")
        { id: customer_id, descriptive_name: nil }
      end
    end

    private

    def fetch_customer_details_via_rest(customer_id, query)
      require "signet/oauth_2/client"

      Rails.logger.info("[GoogleAds::CustomerService] fetch_customer_details_via_rest for customer_id: #{customer_id}")
      Rails.logger.info("[GoogleAds::CustomerService] Using google_account login_customer_id: #{@google_account.login_customer_id}")

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
        Rails.logger.error("[GoogleAds::CustomerService] Failed to get access token")
        return nil
      end

      Rails.logger.info("[GoogleAds::CustomerService] Got access token, making request to customer #{customer_id}")

      # Use the customer_id directly in the URL - this is the account we want to query
      uri = URI("https://googleads.googleapis.com/v22/customers/#{customer_id}/googleAds:search")
      
      request_body = { query: query }
      
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      
      # Add login-customer-id header if we have one (for MCC accounts)
      if @google_account.login_customer_id.present?
        req["login-customer-id"] = @google_account.login_customer_id
        Rails.logger.info("[GoogleAds::CustomerService] Added login-customer-id header: #{@google_account.login_customer_id}")
      end
      
      req.body = request_body.to_json
      
      Rails.logger.debug("[GoogleAds::CustomerService] Request body: #{request_body.to_json}")

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      unless res.code.to_i == 200
        error_body = res.body.force_encoding("UTF-8") rescue res.body
        Rails.logger.error("[GoogleAds::CustomerService] REST API error: #{res.code} - #{error_body[0..200]}")
        return nil
      end

      data = JSON.parse(res.body)
      results = data["results"] || []
      
      Rails.logger.info("[GoogleAds::CustomerService] REST API response: #{results.count} results")
      
      return nil if results.empty?

      # Log the first result structure for debugging
      first_result = results.first
      Rails.logger.info("[GoogleAds::CustomerService] First result keys: #{first_result.keys.inspect}")
      Rails.logger.info("[GoogleAds::CustomerService] First result (full): #{first_result.inspect[0..1000]}")
      
      # The REST API returns results in GoogleAdsRow format
      # Each row has a "customer" field
      customer_data = first_result["customer"]
      
      if customer_data.nil?
        Rails.logger.warn("[GoogleAds::CustomerService] No customer field in result. Available keys: #{first_result.keys.inspect}")
        Rails.logger.warn("[GoogleAds::CustomerService] Full result structure: #{JSON.pretty_generate(first_result)[0..1000]}")
        return nil
      end
      
      Rails.logger.info("[GoogleAds::CustomerService] Customer data keys: #{customer_data.keys.inspect}")
      Rails.logger.info("[GoogleAds::CustomerService] Customer data (full): #{customer_data.inspect[0..1000]}")
      
      # Try multiple possible field names
      descriptive_name = customer_data["descriptiveName"] || 
                         customer_data["descriptive_name"] || 
                         customer_data[:descriptive_name] ||
                         customer_data[:descriptiveName]
      
      Rails.logger.info("[GoogleAds::CustomerService] Found descriptive_name: #{descriptive_name.inspect}")
      
      if descriptive_name.blank?
        Rails.logger.warn("[GoogleAds::CustomerService] descriptive_name is blank. Customer data: #{JSON.pretty_generate(customer_data)[0..500]}")
      end

      {
        id: customer_data["id"] || customer_id,
        descriptive_name: descriptive_name
      }
    end
  end
end
