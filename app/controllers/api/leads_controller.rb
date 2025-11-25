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
      # Permitir todos os filtros necessários, incluindo arrays
      filters = params.permit(
        :period,
        :start_date,
        :end_date,
        :page_size,
        :page_token,
        charge_status: [],
        feedback_status: []
      ).to_h.symbolize_keys
      
      # Normalize arrays - remove empty values
      filters[:charge_status] = Array(filters[:charge_status]).reject(&:blank?) if filters[:charge_status]
      filters[:feedback_status] = Array(filters[:feedback_status]).reject(&:blank?) if filters[:feedback_status]
      
      # Remove empty arrays
      filters.delete(:charge_status) if filters[:charge_status]&.empty?
      filters.delete(:feedback_status) if filters[:feedback_status]&.empty?
      
      filters
    end
  end
end

