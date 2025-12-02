module Api
  module GoogleAds
    class CampaignsController < Api::BaseController
      def index
        selection = current_user.active_customer_selection
        return render_error("Selecione uma conta antes de consultar as campanhas") unless selection

        service = ::GoogleAds::CampaignService.new(
          google_account: selection.google_account,
          customer_id: selection.customer_id
        )

        campaigns = service.list_campaigns

        render json: { campaigns: campaigns }
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        error_message = "Erro ao buscar campanhas: #{e.message}"
        Rails.logger.error("[Api::GoogleAds::CampaignsController] #{error_message}")
        render_error(error_message, :unprocessable_entity)
      rescue => e
        error_message = "Erro inesperado ao buscar campanhas: #{e.message}"
        Rails.logger.error("[Api::GoogleAds::CampaignsController] #{error_message}")
        render_error(error_message, :internal_server_error)
      end

      def locations
        selection = current_user.active_customer_selection
        return render_error("Selecione uma conta antes de consultar as localizações") unless selection

        campaign_id = params[:campaign_id]
        return render_error("campaign_id é obrigatório") unless campaign_id.present?

        service = ::GoogleAds::GetGeoTargets.new(
          google_account: selection.google_account,
          customer_id: selection.customer_id,
          campaign_id: campaign_id
        )

        existing_targets = service.fetch_existing_targets

        # Extract location names from geo_target_constant resource names
        locations = existing_targets.map do |target|
          geo_target_constant = target[:geo_target_constant]
          if geo_target_constant
            # Extract criteria_id from "geoTargetConstants/123456"
            criteria_id = geo_target_constant.split('/').last
            geo_target = GeoTarget.find_by(criteria_id: criteria_id)
            {
              resource_name: target[:resource_name],
              geo_target_constant: geo_target_constant,
              name: geo_target&.name || geo_target_constant,
              criteria_id: criteria_id
            }
          else
            {
              resource_name: target[:resource_name],
              geo_target_constant: nil,
              name: 'Unknown',
              criteria_id: nil
            }
          end
        end

        render json: { locations: locations }
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        error_message = "Erro ao buscar localizações: #{e.message}"
        Rails.logger.error("[Api::GoogleAds::CampaignsController] #{error_message}")
        render_error(error_message, :unprocessable_entity)
      rescue => e
        error_message = "Erro inesperado ao buscar localizações: #{e.message}"
        Rails.logger.error("[Api::GoogleAds::CampaignsController] #{error_message}")
        render_error(error_message, :internal_server_error)
      end
    end
  end
end

