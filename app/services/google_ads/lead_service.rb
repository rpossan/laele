require "ostruct"

module GoogleAds
  class LeadService
    DEFAULT_PAGE_SIZE = 25

    def initialize(google_account:, customer_id:)
      @google_account = google_account
      @customer_id = customer_id
      client = ClientBuilder.new(google_account:).build
      @service = client.service.google_ads
    end

    def list_leads(filters:, page_size:, page_token: nil)
      query = LeadQueryBuilder.new(filters).to_gaql

      Rails.logger.info("[GoogleAds::LeadService] Query: #{query}")
      Rails.logger.info("[GoogleAds::LeadService] Customer ID: #{customer_id}")
      Rails.logger.info("[GoogleAds::LeadService] Login Customer ID: #{google_account.login_customer_id}")

      # Convert page_size to integer if it's a string
      page_size_int = if page_size.is_a?(String)
        page_size.to_i
      elsif page_size.present?
        page_size.to_i
      else
        DEFAULT_PAGE_SIZE
      end

      # Ensure page_size is at least 1
      page_size_int = [ page_size_int, 1 ].max

      Rails.logger.info("[GoogleAds::LeadService] Page size: #{page_size_int}")

      # According to documentation, SearchStream should work in v22
      # Try using search_stream first
      begin
        Rails.logger.info("[GoogleAds::LeadService] Trying search_stream...")
        # search_stream returns an enumerable of SearchGoogleAdsStreamResponse objects
        response_enum = @service.search_stream(
          customer_id: customer_id,
          query: query
        )

        # Collect all results first (Google Ads API doesn't support server-side pagination with search_stream)
        all_results = []
        response_enum.each do |response|
          # Each response contains results array
          if response.respond_to?(:results) && response.results
            response.results.each do |row|
              all_results << row
            end
          end
        end

        Rails.logger.info("[GoogleAds::LeadService] Response received, processing #{all_results.size} total leads...")

        # Convert all results to lead objects
        all_leads = all_results.map do |row|
          # Each row has a local_services_lead field
          lead_data = row.local_services_lead
          LocalServicesLeadPresenter.new(lead_data).as_json
        end

        # Apply client-side filtering for charge statuses if needed
        filtered_leads = apply_client_side_filters(all_leads, filters)

        Rails.logger.info("[GoogleAds::LeadService] Found #{filtered_leads.count} leads after filtering")

        # Return all leads (no backend pagination; DataTables handles paging/search/sort on the client)
        total_count = filtered_leads.size
        {
          leads: filtered_leads,
          next_page_token: nil,
          total_count: total_count,
          current_page: 1,
          total_pages: 1,
          gaql: query
        }
      rescue GRPC::Unimplemented => e
        Rails.logger.warn("[GoogleAds::LeadService] search_stream not available via gRPC, trying REST API...")
        list_leads_via_rest(query, page_size_int, page_token, filters)
      rescue => e
        Rails.logger.error("[GoogleAds::LeadService] Error with search_stream: #{e.class} - #{e.message}")
        Rails.logger.error("[GoogleAds::LeadService] Backtrace: #{e.backtrace.first(5).join("\n")}")
        raise e
      end
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      Rails.logger.error("[GoogleAds::LeadService] GoogleAdsError: #{e.class}")
      Rails.logger.error("[GoogleAds::LeadService] Message: #{e.message}")

      if e.respond_to?(:failure) && e.failure
        e.failure.errors.each do |error|
          Rails.logger.error("[GoogleAds::LeadService] Error code: #{error.error_code}")
          Rails.logger.error("[GoogleAds::LeadService] Error message: #{error.message}")
        end
      end

      raise e
    rescue => e
      Rails.logger.error("[GoogleAds::LeadService] Unexpected error: #{e.class} - #{e.message}")
      Rails.logger.error("[GoogleAds::LeadService] Backtrace: #{e.backtrace.first(10).join("\n")}")
      raise e
    end

    def find_lead(lead_id)
      # Build query to find a specific lead by ID
      query = <<~GAQL
        SELECT
          local_services_lead.resource_name,
          local_services_lead.id,
          local_services_lead.category_id,
          local_services_lead.service_id,
          local_services_lead.contact_details,
          local_services_lead.lead_type,
          local_services_lead.lead_status,
          local_services_lead.creation_date_time,
          local_services_lead.locale,
          local_services_lead.lead_charged,
          local_services_lead.lead_feedback_submitted,
          local_services_lead.credit_details.credit_state,
          local_services_lead.credit_details.credit_state_last_update_date_time
        FROM local_services_lead
        WHERE local_services_lead.id = #{lead_id.to_i}
      GAQL

      Rails.logger.info("[GoogleAds::LeadService] Finding lead #{lead_id}")

      begin
        # Try REST API first (more reliable)
        result = find_lead_via_rest(query)
        return result if result
      rescue => e
        Rails.logger.warn("[GoogleAds::LeadService] REST API failed, trying gRPC: #{e.message}")
      end

      # Fallback to gRPC
      begin
        response_enum = @service.search_stream(
          customer_id: customer_id,
          query: query
        )

        response_enum.each do |response|
          if response.respond_to?(:results) && response.results.any?
            row = response.results.first
            return row.local_services_lead if row.respond_to?(:local_services_lead)
          end
        end
      rescue => e
        Rails.logger.error("[GoogleAds::LeadService] Error finding lead: #{e.message}")
      end

      nil
    end

    private

    attr_reader :google_account, :customer_id

    def list_leads_via_rest(query, page_size_int, page_token = nil, filters = {})
      require "net/http"
      require "uri"
      require "json"

      # Get access token
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
        raise "Falha ao obter access token"
      end

      # Use REST API to search
      # POST https://googleads.googleapis.com/v22/customers/{customerId}/googleAds:search
      uri = URI("https://googleads.googleapis.com/v22/customers/#{customer_id}/googleAds:search")

      # Don't use pageToken for manual pagination - just get all results
      request_body = {
        query: query
      }

      # Note: We don't use pageToken here since we're doing manual pagination

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      req.body = request_body.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      unless res.code.to_i == 200
        error_body = res.body.force_encoding("UTF-8") rescue res.body
        Rails.logger.error("[GoogleAds::LeadService] REST API error: #{res.code}")
        Rails.logger.error("[GoogleAds::LeadService] Response body: #{error_body[0..500]}")
        raise "Google Ads API error: #{res.code} - #{error_body[0..200]}"
      end

      # Parse the response
      # Response structure: { "results": [...], "nextPageToken": "..." }
      data = JSON.parse(res.body)

      results = data["results"] || []

      Rails.logger.info("[GoogleAds::LeadService] Response received, processing #{results.size} total leads...")

      # Convert REST API response to lead objects
      all_leads = results.map do |result|
        # REST API returns GoogleAdsRow: { "localServicesLead": { ... } }
        lead_data_hash = result["localServicesLead"] || result["local_services_lead"]

        unless lead_data_hash
          Rails.logger.warn("[GoogleAds::LeadService] No localServicesLead in result: #{result.keys.inspect}")
          next
        end

        # Log contact_details structure only if it has multiple fields (not just phone)
        contact_details = lead_data_hash["contactDetails"] || lead_data_hash["contact_details"]
        if contact_details && contact_details.is_a?(Hash) && contact_details.keys.count > 1
          Rails.logger.debug("[GoogleAds::LeadService] contactDetails with multiple fields: #{contact_details.keys.inspect}")
        end

        # Recursively convert hash to OpenStruct to handle nested objects
        lead_obj = hash_to_openstruct(lead_data_hash)
        LocalServicesLeadPresenter.new(lead_obj).as_json
      end.compact

      # Apply client-side filtering for charge statuses if needed
      filtered_leads = apply_client_side_filters(all_leads, filters)

      Rails.logger.info("[GoogleAds::LeadService] Found #{filtered_leads.count} leads after filtering")

      total_count = filtered_leads.size
      {
        leads: filtered_leads,
        next_page_token: nil,
        total_count: total_count,
        current_page: 1,
        total_pages: 1,
        gaql: query
      }
    end

    private

    def find_lead_via_rest(query)
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

      uri = URI("https://googleads.googleapis.com/v22/customers/#{customer_id}/googleAds:search")

      request_body = { query: query }

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      req["developer-token"] = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
      req["Content-Type"] = "application/json"
      req.body = request_body.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

      return nil unless res.code.to_i == 200

      data = JSON.parse(res.body)
      results = data["results"] || []

      return nil if results.empty?

      lead_data_hash = results.first["localServicesLead"] || results.first["local_services_lead"]
      return nil unless lead_data_hash

      # Log contactDetails before conversion
      if lead_data_hash["contactDetails"]
        Rails.logger.debug("[GoogleAds::LeadService] contactDetails (before conversion): #{lead_data_hash["contactDetails"].inspect}")
      end

      hash_to_openstruct(lead_data_hash)
    end

    def hash_to_openstruct(obj)
      case obj
      when Hash
        # Convert camelCase keys to snake_case for OpenStruct method access
        # OpenStruct uses method_missing, so keys need to be valid method names
        converted = {}
        obj.each do |key, value|
          # Convert camelCase to snake_case (e.g., "contactDetails" -> "contact_details")
          snake_key = key.to_s.gsub(/([A-Z])/, '_\1').downcase.gsub(/^_/, "")
          converted[snake_key] = hash_to_openstruct(value)

          # Also preserve original camelCase key as string for hash access
          # This allows both contact_details (method) and "contactDetails" (hash) access
          if key.to_s != snake_key
            converted[key.to_s] = hash_to_openstruct(value)
          end
        end
        ::OpenStruct.new(converted)
      when Array
        obj.map { |item| hash_to_openstruct(item) }
      else
        obj
      end
    end

    def apply_client_side_filters(leads, filters)
      return leads unless filters[:charge_status]

      charge_statuses = Array(filters[:charge_status])
      return leads if charge_statuses.empty?

      # Check if we need client-side filtering
      needs_client_filtering = charge_statuses.any? { |status| [ "not_charged", "rejected", "credited", "in_review" ].include?(status) }
      return leads unless needs_client_filtering

      Rails.logger.info("[GoogleAds::LeadService] Applying client-side filtering for: #{charge_statuses.join(', ')}")

      # Filter leads based on charge status
      filtered_leads = leads.select do |lead|
        lead_charged = lead[:lead_charged] || lead["lead_charged"]
        credit_state = lead[:credit_state] || lead["credit_state"]

        # Determine the actual status of this lead
        actual_status = if lead_charged
          "charged"
        elsif credit_state == "CREDITED"
          "credited"
        elsif credit_state == "PENDING"
          "in_review"
        elsif credit_state == "UNKNOWN"
          # In v22, UNKNOWN could be considered as "rejected" in some contexts
          # But we'll treat it as "not_charged" for now since there's no clear "rejected" state
          "not_charged"
        else
          # nil, empty, or UNSPECIFIED
          "not_charged"
        end

        # Check if this lead matches any of the requested statuses
        matches = charge_statuses.include?(actual_status)

        # Special handling for "rejected" - since there's no clear rejected state in v22,
        # we might need to infer it from other conditions
        if charge_statuses.include?("rejected") && !matches
          # A lead could be considered "rejected" if it's not charged and has UNKNOWN state
          # This is an assumption - you may need to adjust based on actual business logic
          matches = !lead_charged && credit_state == "UNKNOWN"
        end

        Rails.logger.debug("[GoogleAds::LeadService] Lead #{lead[:id]}: charged=#{lead_charged}, credit_state=#{credit_state}, actual_status=#{actual_status}, matches=#{matches}")

        matches
      end

      Rails.logger.info("[GoogleAds::LeadService] Filtered from #{leads.size} to #{filtered_leads.size} leads")
      filtered_leads
    end
  end
end
