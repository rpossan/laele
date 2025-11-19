module Api
  class LeadsController < Api::BaseController
    def index
      selection = current_user.active_customer_selection
      return render_error("Selecione uma conta antes de consultar os leads") unless selection

      service = ::GoogleAds::LeadService.new(
        google_account: selection.google_account,
        customer_id: selection.customer_id
      )

      result = service.list_leads(
        filters: permitted_filters,
        page_size: params[:page_size],
        page_token: params[:page_token]
      )

      render json: result
    end

    private

    def permitted_filters
      params.permit(:period, :charge_status, :feedback_status, :start_date, :end_date).to_h.symbolize_keys
    end
  end
end

