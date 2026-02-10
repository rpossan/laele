class GeographicSearchService
  # Service for searching geographic locations within selected states
  # Implements two-stage geographic search:
  # 1. State selection (whitelist)
  # 2. Location search within selected states

  def initialize(selected_states)
    @selected_states = normalize_states(selected_states)
  end

  # Search for locations matching the query within selected states
  # @param query [String] Search term (e.g., "Duluth", "30301", "Duluth, GA")
  # @param limit [Integer] Maximum number of results to return
  # @return [Array<Hash>] Array of matching locations with city, county, state, zip_code
  def search(query, limit: 20)
    return [] if query.blank? || @selected_states.empty?

    normalized_query = query.strip
    
    # Parse the query to extract search terms
    search_terms = parse_query(normalized_query)
    
    # Build the database query
    results = find_matching_locations(search_terms, limit)
    
    # Format results for API response
    format_results(results)
  end

  # Check if any states are selected
  # @return [Boolean]
  def states_selected?
    @selected_states.present?
  end

  # Get the selected states
  # @return [Array<String>] Array of state codes
  def selected_states
    @selected_states
  end

  private

  # Normalize state codes to uppercase
  # @param states [Array, String] State codes or names
  # @return [Array<String>] Normalized state codes
  def normalize_states(states)
    return [] if states.blank?

    state_array = states.is_a?(Array) ? states : [states]
    state_array.map { |s| s.to_s.strip.upcase }.compact.uniq
  end

  # Parse the search query into individual search terms
  # Handles formats like:
  # - "Duluth" -> searches city
  # - "30301" -> searches zip code
  # - "Duluth, GA" -> searches city and state (but state is ignored, uses selected states)
  # - "Duluth, Fulton" -> searches city and county
  #
  # @param query [String] Raw search query
  # @return [Hash] Parsed search terms with keys: :city, :county, :zip_code
  def parse_query(query)
    terms = {}
    
    # Split by comma to handle multi-part queries
    parts = query.split(',').map(&:strip)
    
    parts.each do |part|
      if part.match?(/^\d{5}$/)
        # ZIP code format (5 digits)
        terms[:zip_code] = part
      elsif part.match?(/^[A-Z]{2}$/i)
        # State code format (2 letters) - ignore, we use selected states
        next
      else
        # Treat as city or county name
        # Try to determine if it's a city or county based on context
        # For now, we'll search both city and county
        if terms[:city].blank?
          terms[:city] = part
        elsif terms[:county].blank?
          terms[:county] = part
        end
      end
    end
    
    terms
  end

  # Find matching locations in the database
  # Uses AddressGeographicMapping to find locations within selected states
  #
  # @param search_terms [Hash] Parsed search terms
  # @param limit [Integer] Maximum results
  # @return [ActiveRecord::Relation] Query results
  def find_matching_locations(search_terms, limit)
    query = AddressGeographicMapping.where(state: @selected_states, country_code: "US")
    
    # Apply search term filters
    if search_terms[:zip_code].present?
      query = query.where(zip_code: search_terms[:zip_code])
    end
    
    if search_terms[:city].present?
      # Case-insensitive city search with LIKE
      query = query.where("LOWER(city) LIKE LOWER(?)", "%#{search_terms[:city]}%")
    end
    
    if search_terms[:county].present?
      # Case-insensitive county search with LIKE
      query = query.where("LOWER(county) LIKE LOWER(?)", "%#{search_terms[:county]}%")
    end
    
    # Order by state, then city for consistent results
    query.order(:state, :city).limit(limit)
  end

  # Format results for API response
  # Removes duplicates and returns unique city-state combinations
  #
  # @param results [ActiveRecord::Relation] Database query results
  # @return [Array<Hash>] Formatted results
  def format_results(results)
    # Group by city-state-zip to remove duplicates
    unique_results = {}
    
    results.each do |record|
      key = "#{record.city}|#{record.state}|#{record.zip_code}"
      unique_results[key] ||= {
        city: record.city,
        county: record.county,
        state: record.state,
        zip_code: record.zip_code,
        country_code: record.country_code,
        display_name: "#{record.city}, #{record.state} #{record.zip_code}"
      }
    end
    
    unique_results.values
  end
end
