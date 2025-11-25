class LeadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_active_selection

  def index
    # Render the same dashboard view
    render "dashboard/show"
  end

  def show
    @lead_id = params[:id]
    
    # Preserve query parameters for "Voltar" button
    # Convert to hash and remove nil/empty values
    back_params = params.slice(:period, :charge_status, :feedback_status, :page_size, :page_token).permit!
    @back_params = back_params.to_h.reject { |k, v| v.blank? }.presence
    
    unless @active_selection
      redirect_to dashboard_path, alert: "Selecione uma conta antes de visualizar os detalhes do lead."
      return
    end

    service = ::GoogleAds::LeadService.new(
      google_account: @active_selection.google_account,
      customer_id: @active_selection.customer_id
    )

    lead_data = service.find_lead(@lead_id)
    
    unless lead_data
      redirect_to dashboard_path(@back_params), alert: "Lead não encontrado."
      return
    end

    @lead = LocalServicesLeadPresenter.new(lead_data)
    
    # Debug: Log the raw lead data structure
    Rails.logger.debug("[LeadsController] Lead data class: #{lead_data.class}")
    Rails.logger.debug("[LeadsController] Lead data inspect: #{lead_data.inspect[0..500]}")
    if lead_data.respond_to?(:contact_details)
      Rails.logger.debug("[LeadsController] contact_details: #{lead_data.contact_details.inspect[0..500]}")
    elsif lead_data.respond_to?(:contactDetails)
      Rails.logger.debug("[LeadsController] contactDetails: #{lead_data.contactDetails.inspect[0..500]}")
    end
  end

  private

  def set_active_selection
    @active_selection = current_user.active_customer_selection
  end

  helper_method :status_color_class, :format_lead_status, :format_category_id, :format_service_id

  def status_color_class(status)
    case status&.to_s
    when "NEW"
      "bg-blue-400/20 text-blue-300"
    when "CONTACTED"
      "bg-yellow-400/20 text-yellow-300"
    when "CONVERTED"
      "bg-emerald-400/20 text-emerald-300"
    when "NOT_CONVERTED"
      "bg-red-400/20 text-red-300"
    else
      "bg-gray-400/20 text-gray-300"
    end
  end

  def format_lead_status(status)
    return "N/A" unless status
    status.to_s.split("_").map { |word| word.capitalize }.join(" ")
  end

  def format_category_id(category_id)
    return "N/A" unless category_id.present?
    
    # Remove prefix and format
    # xcat:service_area_business_landscaper -> Landscaper
    if category_id.start_with?("xcat:service_area_business_")
      category_id.gsub("xcat:service_area_business_", "").split("_").map(&:capitalize).join(" ")
    else
      category_id
    end
  end

  def format_service_id(service_id)
    return "N/A" unless service_id.present?
    
    # Replace underscores with spaces and capitalize each word
    # paving_driveway_walkway -> Paving Driveway Walkway
    service_id.split("_").map(&:capitalize).join(" ")
  end
end

