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
      selection = current_user.active_customer_selection
      return render_error("Selecione uma conta antes de atualizar os targets de localização") unless selection

      customer_id = params[:customer_id] || selection.customer_id
      campaign_id = params[:campaign_id]
      locations = params[:locations]
      country_code = params[:country_code] || "US"

      unless campaign_id.present?
        return render_error("campaign_id é obrigatório")
      end

      unless locations.present?
        return render_error("locations é obrigatório")
      end

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

        # Log activity
        ActivityLogger.log_geo_targets_updated(
          user: current_user,
          campaign_id: campaign_id,
          added_count: result[:added_count] || 0,
          removed_count: result[:removed_count] || 0,
          total_count: result[:total_count] || result[:applied_geo_targets]&.size || 0,
          locations: result[:applied_geo_targets] || [],
          request: request
        )

        render json: result
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        error_message = "Erro ao atualizar targets de localização: #{e.message}"
        Rails.logger.error("[Api::GeoTargetsController] #{error_message}")
        render_error(error_message, :unprocessable_entity)
      rescue => e
        error_message = "Erro inesperado ao atualizar targets de localização: #{e.message}"
        Rails.logger.error("[Api::GeoTargetsController] #{error_message}")
        Rails.logger.error("[Api::GeoTargetsController] Backtrace: #{e.backtrace.first(10).join("\n")}")
        render_error(error_message, :internal_server_error)
      end
    end
  end
end
