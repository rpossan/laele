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
      # Contact details - extract specific fields
      phone_number: extract_contact_field(:phone_number),
      consumer_name: extract_contact_field(:consumer_name),
      email: extract_contact_field(:email) || extract_contact_field(:consumer_email),
      consumer_email: extract_contact_field(:email) || extract_contact_field(:consumer_email),
      postal_code: extract_contact_field(:postal_code),
      city: extract_contact_field(:city),
      address: extract_contact_field(:address),
      message: extract_contact_field(:message),
      lead_type: lead.lead_type,
      lead_status: lead.lead_status,
      creation_date_time: lead.creation_date_time,
      locale: lead.locale,
      lead_charged: lead_charged_value,
      # lead_feedback_submitted: if field doesn't exist, treat as false
      # When true, it appears in JSON. When false, field often doesn't exist
      lead_feedback_submitted: lead_feedback_submitted_value,
      credit_state: lead.credit_details&.credit_state,
      credit_state_last_update: lead.credit_details&.credit_state_last_update_date_time
    }
  end

  # View-friendly methods
  def id
    lead.id
  end

  def lead_type
    lead.lead_type
  end

  def status
    lead.lead_status
  end

  def charged?
    lead.lead_charged == true || lead.lead_charged == "true"
  end

  def feedback_submitted?
    lead_feedback_submitted_value
  end

  def created_at
    return nil unless lead.creation_date_time
    Time.parse(lead.creation_date_time.to_s) rescue lead.creation_date_time
  end

  def phone
    extract_contact_field(:phone_number)
  end

  def email
    # API returns 'email' not 'consumer_email' in contact_details
    # Try direct access first since we know it's in the OpenStruct
    contact_details = lead.contact_details || lead.contactDetails || lead["contact_details"] || lead["contactDetails"]
    
    if contact_details
      # Try direct method access
      if contact_details.respond_to?(:email)
        value = contact_details.email
        Rails.logger.debug("[LocalServicesLeadPresenter] Email found via .email method: #{value.inspect}")
        return value if value.present?
      end
      
      # Try hash access
      if contact_details.respond_to?(:[])
        value = contact_details["email"] || contact_details[:email]
        Rails.logger.debug("[LocalServicesLeadPresenter] Email found via [] access: #{value.inspect}")
        return value if value.present?
      end
      
      # Try @table access for OpenStruct
      if contact_details.is_a?(::OpenStruct)
        table = contact_details.instance_variable_get(:@table)
        if table
          value = table["email"] || table[:email]
          Rails.logger.debug("[LocalServicesLeadPresenter] Email found via @table: #{value.inspect}")
          return value if value.present?
        end
      end
    end
    
    # Fallback to extract_contact_field
    email_value = extract_contact_field(:email) || extract_contact_field(:consumer_email)
    Rails.logger.debug("[LocalServicesLeadPresenter] Email extracted via extract_contact_field: #{email_value.inspect}")
    email_value
  end

  def name
    extract_contact_field(:consumer_name)
  end

  def charge_status
    return "Charged" if charged?
    case lead.credit_details&.credit_state
    when "CREDITED"
      "Credited"
    when "PENDING"
      "In review"
    else
      # For v22 API: UNKNOWN, UNSPECIFIED, or nil means not charged
      # There's no specific "rejected" state in v22
      "Not charged"
    end
  end

  def feedback_status
    feedback_submitted? ? "Com feedback" : "Sem feedback"
  end

  def resource_name
    lead.resource_name
  end

  def category_id
    lead.category_id
  end

  def service_id
    lead.service_id
  end

  private

  def lead_feedback_submitted_value
    # Handle both OpenStruct (from REST) and protobuf objects
    # REST API may return camelCase: leadFeedbackSubmitted
    # gRPC may return snake_case: lead_feedback_submitted
    
    # Try snake_case first (gRPC)
    if lead.respond_to?(:lead_feedback_submitted)
      value = lead.lead_feedback_submitted
      Rails.logger.debug("[LocalServicesLeadPresenter] lead_feedback_submitted (snake_case): #{value.inspect}")
      return true if value == true || value == "true" || value == true.to_s
    end
    
    # Try camelCase (REST API format)
    if lead.respond_to?(:leadFeedbackSubmitted)
      value = lead.leadFeedbackSubmitted
      Rails.logger.debug("[LocalServicesLeadPresenter] leadFeedbackSubmitted (camelCase): #{value.inspect}")
      return true if value == true || value == "true" || value == true.to_s
    end
    
    # Try accessing as hash (REST API JSON)
    if lead.respond_to?(:[])
      value = lead["lead_feedback_submitted"] || lead["leadFeedbackSubmitted"]
      Rails.logger.debug("[LocalServicesLeadPresenter] lead_feedback_submitted (hash): #{value.inspect}")
      return true if value == true || value == "true" || value == true.to_s
    end
    
    # Try accessing nested in contactDetails or other nested structures
    if lead.respond_to?(:to_h)
      hash = lead.to_h
      value = hash["lead_feedback_submitted"] || hash["leadFeedbackSubmitted"] || 
              hash[:lead_feedback_submitted] || hash[:leadFeedbackSubmitted]
      Rails.logger.debug("[LocalServicesLeadPresenter] lead_feedback_submitted (to_h): #{value.inspect}")
      return true if value == true || value == "true" || value == true.to_s
    end
    
    Rails.logger.debug("[LocalServicesLeadPresenter] lead_feedback_submitted: NOT FOUND, returning false")
    false
  end

  def extract_contact_field(field_name)
    # Handle different formats: snake_case, camelCase, or nested object
    # REST API returns: contactDetails.phoneNumber
    # gRPC returns: contact_details.phone_number
    # API requires selecting contact_details as a whole object, not individual fields
    
    # Convert field_name to camelCase for REST API
    # consumer_email -> consumerEmail
    camel_field = field_name.to_s.split('_').map.with_index { |w, i| i == 0 ? w : w.capitalize }.join
    
    # Get contact_details object
    contact_details = nil
    
    # Try snake_case first (gRPC)
    if lead.respond_to?(:contact_details)
      contact_details = lead.contact_details
    # Try camelCase (REST API)
    elsif lead.respond_to?(:contactDetails)
      contact_details = lead.contactDetails
    # Try as hash access
    elsif lead.respond_to?(:[])
      contact_details = lead["contact_details"] || lead["contactDetails"]
    end
    
    return nil unless contact_details
    
    # Extract field from contact_details object
    # Try snake_case first (e.g., consumer_email)
    if contact_details.respond_to?(field_name)
      value = contact_details.public_send(field_name)
      return value unless value.nil? || value == ""
    end
    
    # Try camelCase (e.g., consumerEmail)
    if contact_details.respond_to?(camel_field)
      value = contact_details.public_send(camel_field)
      return value unless value.nil? || value == ""
    end
    
    # Try hash access (string keys)
    if contact_details.is_a?(Hash)
      value = contact_details[field_name.to_s] || contact_details[field_name.to_sym] || 
              contact_details[camel_field] || contact_details[camel_field.to_sym]
      return value unless value.nil? || value == ""
    end
    
    # Try OpenStruct-like access
    if contact_details.respond_to?(:[])
      value = contact_details[field_name.to_s] || contact_details[field_name.to_sym] ||
              contact_details[camel_field] || contact_details[camel_field.to_sym]
      return value unless value.nil? || value == ""
    end
    
    # Try to_h conversion for OpenStruct
    if contact_details.respond_to?(:to_h)
      hash = contact_details.to_h
      value = hash[field_name.to_s] || hash[field_name.to_sym] || 
              hash[camel_field] || hash[camel_field.to_sym]
      return value unless value.nil? || value == ""
    end
    
    # Try accessing @table directly for OpenStruct
    if contact_details.is_a?(::OpenStruct)
      table = contact_details.instance_variable_get(:@table)
      if table
        # Try all possible key formats
        value = table[field_name.to_sym] || 
                table[field_name.to_s] ||
                table[camel_field.to_sym] ||
                table[camel_field] ||
                # Try with different case variations
                table[field_name.to_s.downcase.to_sym] ||
                table[camel_field.downcase.to_sym]
        return value unless value.nil? || value == ""
      end
    end
    nil
  end

  def lead_charged_value
    # Debug the actual value of lead_charged
    raw_value = lead.lead_charged
    Rails.logger.debug("[LocalServicesLeadPresenter] lead_charged raw value: #{raw_value.inspect} (class: #{raw_value.class})")
    
    # Return the actual value, don't default to false
    case raw_value
    when true, "true"
      true
    when false, "false"
      false
    when nil
      nil
    else
      Rails.logger.warn("[LocalServicesLeadPresenter] Unexpected lead_charged value: #{raw_value.inspect}")
      raw_value
    end
  end

  private

  attr_reader :lead
end

