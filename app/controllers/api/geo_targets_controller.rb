module Api
  class GeoTargetsController < Api::BaseController
    def search
      query = params[:q] || params[:term] || ""
      country_code = params[:country_code] || "US"
      limit = params[:limit] || 20

      return render json: { results: [] } if query.blank? || query.length < 2

      lookup_service = ::GoogleAds::OfflineGeoLookup.new(country_code: country_code)
      results = lookup_service.search(query, limit: limit.to_i)

      # Format for Select2
      formatted_results = results.map do |result|
        {
          id: result[:id],
          text: "#{result[:name]} (#{result[:type]})"
        }
      end

      render json: { results: formatted_results }
    end

    def update
      campaign_id = params[:campaign_id]
      locations = params[:locations]
      country_code = params[:country_code] || "US"

      unless campaign_id.present?
        return render_error("campaign_id é obrigatório")
      end

      unless locations.present?
        return render_error("locations é obrigatório")
      end

      selection = current_user.active_customer_selection
      return render_error("Selecione uma conta antes de atualizar os targets de localização") unless selection

      customer_id = params[:customer_id] || selection.customer_id

      # Normalize locations to array (can be string, array, or array of resource names)
      locations_array = if locations.is_a?(Array)
        locations
      elsif locations.is_a?(String)
        # If it's a comma-separated string, split it
        # Otherwise, treat as single location
        locations.include?(',') ? locations.split(',').map(&:strip) : [locations]
      else
        Array(locations)
      end

      # Filter out empty strings and validate
      locations_array = locations_array.reject { |loc| loc.to_s.strip.blank? }

      unless locations_array.present?
        return render_error("locations é obrigatório")
      end

      Rails.logger.info("[Api::GeoTargetsController] Updating geo targets for campaign #{campaign_id}")
      Rails.logger.info("[Api::GeoTargetsController] Locations: #{locations_array.inspect}")
      Rails.logger.info("[Api::GeoTargetsController] Country code: #{country_code}")

      begin
        service = Lsa::ApplyGeoTargets.new(
          google_account: selection.google_account,
          customer_id: customer_id,
          campaign_id: campaign_id
        )

        result = service.apply(locations_array, country_code: country_code)

        # Ensure total_count is always present
        result[:total_count] ||= result[:applied_geo_targets]&.size || 0

        # Log activity
        ActivityLogger.log_geo_targets_updated(
          user: current_user,
          campaign_id: campaign_id,
          added_count: result[:added_count] || 0,
          removed_count: result[:removed_count] || 0,
          total_count: result[:total_count],
          locations: result[:applied_geo_targets] || [],
          request: request
        )

        render json: result
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        # Extract detailed error message from Google Ads API response
        detailed_error = extract_google_ads_error_details(e)
        error_message = "Erro ao atualizar targets de localização: #{detailed_error}"
        Rails.logger.error("[Api::GeoTargetsController] #{error_message}")
        render_error(error_message, :unprocessable_entity)
      rescue => e
        # Extract detailed error message if it's a RuntimeError from API
        detailed_error = extract_api_error_details(e)
        error_message = "Erro ao atualizar targets de localização: #{detailed_error}"
        Rails.logger.error("[Api::GeoTargetsController] #{error_message}")
        Rails.logger.error("[Api::GeoTargetsController] Backtrace: #{e.backtrace.first(10).join("\n")}")
        render_error(error_message, :internal_server_error)
      end
    end

    private

    def extract_google_ads_error_details(error)
      # Try to extract error details from Google Ads error
      error.message
    end

    def extract_api_error_details(error)
      # Check if error message contains JSON from API response
      if error.message.include?("Google Ads API error:")
        # Try to parse and extract the actual error message
        begin
          # Extract JSON from error message
          json_start = error.message.index('{')
          json_end = error.message.rindex('}')
          
          if json_start && json_end
            json_str = error.message[json_start..json_end]
            error_data = JSON.parse(json_str)
            
            # Extract the most relevant error message
            if error_data['error'] && error_data['error']['details']
              details = error_data['error']['details'].first
              if details && details['errors']
                first_error = details['errors'].first
                # Try to get the specific error message first
                if first_error && first_error['message']
                  return first_error['message']
                end
              end
            end
            
            # Fallback to main error message
            return error_data['error']['message'] if error_data['error'] && error_data['error']['message']
          end
        rescue => parse_error
          Rails.logger.warn("[Api::GeoTargetsController] Failed to parse error details: #{parse_error.message}")
        end
      end
      
      error.message
    end
  end
end
