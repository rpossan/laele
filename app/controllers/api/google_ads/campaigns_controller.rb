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
        render_error(error_message, :unprocessable_content)
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
        formatter = ::GoogleAds::FormatCampaignLocations.new(existing_targets)
        locations = formatter.call

        render json: { locations: locations }
      rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
        error_message = "Erro ao buscar localizações: #{e.message}"
        Rails.logger.error("[Api::GoogleAds::CampaignsController] #{error_message}")
        render_error(error_message, :unprocessable_content)
      rescue => e
        error_message = "Erro inesperado ao buscar localizações: #{e.message}"
        Rails.logger.error("[Api::GoogleAds::CampaignsController] #{error_message}")
        render_error(error_message, :internal_server_error)
      end
    end
  end
end

