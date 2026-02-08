module Api
  class LeadsController < Api::BaseController
    def index
      selection = current_user.active_customer_selection
      return render_error("Selecione uma conta antes de consultar os leads") unless selection

      # Check if states are selected for geographic validation
      state_selector = StateSelector.new(session)
      unless state_selector.any_selected?
        return render_error(GeographicValidatorService.new.blocking_message, :unprocessable_entity)
      end

      service = ::GoogleAds::LeadService.new(
        google_account: selection.google_account,
        customer_id: selection.customer_id
      )

      result = service.list_leads(
        filters: permitted_filters,
        page_size: nil,
        page_token: nil
      )

      # Override feedback status from local table so "Com feedback" shows immediately (Google API can lag)
      leads = merge_local_feedback_status(result[:leads], selection.google_account_id)

      # Add validation results to each lead
      validator = GeographicValidatorService.new(state_selector.selected_states)
      leads = add_validation_results(leads, validator)

      render json: {
        leads: leads,
        total_count: result[:total_count],
        gaql: result[:gaql]
      }
    end

    private

    def add_validation_results(leads, validator)
      leads.map do |lead|
        lead = lead.dup
        
        # Create AddressRecord from lead data
        address_record = AddressRecord.new(
          zip_code: lead[:zip_code],
          city: lead[:city],
          county: lead[:county],
          original_data: lead
        )

        # Validate the address
        validation_result = validator.validate_address(address_record)

        # Add validation data to lead
        lead[:validation] = {
          classification: validation_result.classification,
          state: validation_result.state,
          in_coverage: validation_result.in_coverage?,
          error: validation_result.error
        }

        # Prevent out-of-coverage leads from being sent to search
        lead[:should_search] = !validation_result.out_of_coverage?

        lead
      end
    end

    def merge_local_feedback_status(leads, google_account_id)
      return leads if leads.blank?
      lead_ids = leads.map { |h| h[:id].to_s }.uniq
      stored = LeadFeedbackSubmission
        .where(google_account_id: google_account_id, lead_id: lead_ids)
        .index_by(&:lead_id)
      leads.map do |lead|
        lead = lead.dup
        if stored[lead[:id].to_s]
          lead[:lead_feedback_submitted] = true
          lead[:stored_feedback_available] = true
        end
        lead
      end
    end

    def permitted_filters
      filters = params.permit(
        :period,
        :start_date,
        :end_date,
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
