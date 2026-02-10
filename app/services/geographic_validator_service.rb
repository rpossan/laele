class GeographicValidatorService
  BLOCKING_MESSAGE = "Please select at least one state to validate addresses".freeze

  def initialize(selected_states = [])
    @selected_states = Array(selected_states).map(&:to_s).compact
  end

  # Validate a single address record
  def validate_address(address_record)
    unless address_record.is_a?(AddressRecord)
      return ValidationResult.new(
        address_record: address_record,
        classification: 'invalid_record',
        error: 'Invalid address record type'
      )
    end

    # Check if record is complete
    unless address_record.complete?
      return ValidationResult.new(
        address_record: address_record,
        classification: 'invalid_record',
        error: 'Address record missing required components'
      )
    end

    # Query geographic database for state
    begin
      state = AddressGeographicMapping.find_state(
        zip_code: address_record.zip_code,
        city: address_record.city,
        county: address_record.county
      )
    rescue => e
      Rails.logger.error("Geographic database query failed: #{e.message}")
      return ValidationResult.new(
        address_record: address_record,
        classification: 'unable_to_determine',
        error: "Database query failed: #{e.message}"
      )
    end

    # If state cannot be determined, classify as unable_to_determine
    unless state.present?
      return ValidationResult.new(
        address_record: address_record,
        classification: 'unable_to_determine',
        error: 'State could not be determined from geographic database'
      )
    end

    # Check if state is in selected states
    in_coverage = @selected_states.include?(state)
    classification = in_coverage ? 'in_coverage' : 'out_of_coverage'

    ValidationResult.new(
      address_record: address_record,
      state: state,
      in_coverage: in_coverage,
      classification: classification
    )
  end

  # Validate multiple address records
  def validate_batch(address_records)
    Array(address_records).map { |record| validate_address(record) }
  end

  # Check if states are selected
  def states_selected?
    @selected_states.present?
  end

  # Get blocking message if no states selected
  def blocking_message
    BLOCKING_MESSAGE
  end
end
