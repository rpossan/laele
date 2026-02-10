class StateSelector
  # List of valid US state codes
  VALID_STATES = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ].freeze

  SESSION_KEY = 'selected_states'.freeze

  def initialize(session)
    @session = session
  end

  # Get currently selected states
  def selected_states
    @session[SESSION_KEY] || []
  end

  # Update selected states
  def update_selections(state_codes)
    state_codes = Array(state_codes).map(&:to_s).compact.uniq

    # Validate all state codes
    invalid_states = state_codes - VALID_STATES
    if invalid_states.any?
      return { success: false, error: "Invalid state codes: #{invalid_states.join(', ')}" }
    end

    @session[SESSION_KEY] = state_codes
    { success: true, selected_states: state_codes }
  end

  # Clear all selections
  def clear_selections
    @session[SESSION_KEY] = []
    { success: true, selected_states: [] }
  end

  # Check if any states are selected
  def any_selected?
    selected_states.any?
  end
end
