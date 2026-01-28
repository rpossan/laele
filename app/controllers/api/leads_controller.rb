module Api
  class LeadsController < Api::BaseController
    def index
      selection = current_user.active_customer_selection
      return render_error("Selecione uma conta antes de consultar os leads") unless selection

      service = ::GoogleAds::LeadService.new(
        google_account: selection.google_account,
        customer_id: selection.customer_id
      )

      # Get page from params (default to 1)
      page = params[:page]&.to_i || 1
      
      result = service.list_leads(
        filters: permitted_filters,
        page_size: params[:page_size] || 20,
        page_token: page.to_s
      )

      # Create Pagy object for frontend pagination
      pagy = Pagy.new(
        count: result[:total_count] || 0,
        page: result[:current_page] || 1,
        items: params[:page_size]&.to_i || 20
      )

      render json: {
        leads: result[:leads],
        pagy: pagy_metadata(pagy),
        total_count: result[:total_count],
        current_page: result[:current_page],
        total_pages: result[:total_pages],
        gaql: result[:gaql]
      }
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
        :page,
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

