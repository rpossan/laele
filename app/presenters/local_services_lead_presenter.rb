class LocalServicesLeadPresenter
  def initialize(lead)
    @lead = lead
  end

  def as_json(*)
    {
      id: lead.id,
      resource_name: lead.resource_name,
      category_id: lead.category_id,
      service_id: lead.service_id,
      contact_details: lead.contact_details,
      lead_type: lead.lead_type,
      lead_status: lead.lead_status,
      creation_date_time: lead.creation_date_time,
      locale: lead.locale,
      lead_charged: lead.lead_charged,
      lead_feedback_submitted: !!lead.lead_feedback_submitted,
      credit_state: lead.credit_details&.credit_state,
      credit_state_last_update: lead.credit_details&.credit_state_last_update_date_time
    }
  end

  private

  attr_reader :lead
end

