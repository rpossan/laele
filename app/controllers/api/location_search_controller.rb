module Api
  class LocationSearchController < Api::BaseController
    # POST /api/location_search
    # Search for locations within selected states
    def search
      search_terms = params[:search_terms].to_s.strip
      selected_states = Array(params[:selected_states]).map(&:to_s).compact

      # Validate input
      if search_terms.blank?
        return render_error("Search terms cannot be empty", :unprocessable_entity)
      end

      if selected_states.compact_blank&.blank?
        return render_error("No states selected for search", :unprocessable_entity)
      end

      # Split search terms by comma and process each individually
      terms = search_terms.split(',').map(&:strip).reject(&:blank?)

      if terms.empty?
        return render_error("Search terms cannot be empty", :unprocessable_entity)
      end

      # Process each term individually
      results = []
      unmatched = []

      terms.each do |term|
        parsed = parse_search_terms(term)
        matches = find_matching_locations(parsed, selected_states)

        if matches.empty?
          unmatched << term
        else
          results.concat(matches)
        end
      end

      # Remove duplicates while preserving order
      results = results.uniq { |r| [r[:city], r[:state], r[:zip_code]] }

      render json: {
        success: true,
        results: results,
        unmatched: unmatched,
        count: results.length,
        unmatched_count: unmatched.length
      }
    end

    private

    # Parse search terms to extract city, zip code, county
    # Handles formats like:
    # - "Duluth"
    # - "30301"
    # - "Duluth, 30301"
    # - "Duluth, GA"
    # - "Fulton County"
    def parse_search_terms(search_terms)
      terms = search_terms.split(',').map(&:strip)

      parsed = {
        city: nil,
        zip_code: nil,
        county: nil
      }

      terms.each do |term|
        if term.match?(/^\d{5}$/)
          # ZIP code format (5 digits)
          parsed[:zip_code] = term
        elsif term.match?(/county/i)
          # County format (contains "county")
          parsed[:county] = term.gsub(/\s+county\s*/i, '').strip
        else
          # Assume it's a city name
          parsed[:city] = term
        end
      end

      parsed
    end

    # Query AddressGeographicMapping with whitelist logic
    # Returns all matching instances from selected states
    def find_matching_locations(parsed, selected_states)
      query = AddressGeographicMapping.where(state: selected_states)

      # Apply filters based on parsed search terms (case-insensitive)
      if parsed[:zip_code].present?
        query = query.by_zip_code(parsed[:zip_code])
      end
      
      if parsed[:city].present?
        query = query.where('LOWER(city) = ?', parsed[:city].downcase)
      end
      
      if parsed[:county].present?
        query = query.where('LOWER(county) = ?', parsed[:county].downcase)
      end

      # Return results as array with city, state, zip_code, county
      query.distinct.pluck(:city, :state, :zip_code, :county).map do |city, state, zip_code, county|
        {
          city: city,
          state: state,
          zip_code: zip_code,
          county: county
        }
      end
    end
  end
end
