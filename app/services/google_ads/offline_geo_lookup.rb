module GoogleAds
  class OfflineGeoLookup
    def initialize(country_code: nil, selected_states: nil)
      @country_code = country_code || "US"
      @selected_states = Array(selected_states).map(&:upcase)
    end

    def find(query)
      return [] if query.blank?

      query = query.strip
      results = []

      # Try to find by ZIP code first (most specific)
      if query.match?(/^\d{5}(-\d{4})?$/)
        address_mappings = AddressGeographicMapping.by_zip_code(query)
        address_mappings = filter_by_states(address_mappings)
        address_mappings.each do |mapping|
          result = format_address_result(mapping)
          results << result unless results.any? { |r| r[:id] == result[:id] }
        end
        return results if results.any?
      end

      # Try exact match on city name
      address_mappings = AddressGeographicMapping.by_city(query)
      address_mappings = filter_by_states(address_mappings)
      address_mappings.each do |mapping|
        result = format_address_result(mapping)
        results << result unless results.any? { |r| r[:id] == result[:id] }
      end
      return results if results.any?

      # Try exact match on county name
      address_mappings = AddressGeographicMapping.by_county(query)
      address_mappings = filter_by_states(address_mappings)
      address_mappings.each do |mapping|
        result = format_address_result(mapping)
        results << result unless results.any? { |r| r[:id] == result[:id] }
      end

      results
    end

    def search(query, limit: 20)
      return [] if query.blank?

      query = query.strip
      return [] if query.length < 2

      results = []

      # Search by ZIP code (exact match)
      if query.match?(/^\d{5}(-\d{4})?$/)
        address_mappings = AddressGeographicMapping.by_zip_code(query)
        address_mappings = filter_by_states(address_mappings)
        address_mappings.limit(limit).each do |mapping|
          result = format_address_result(mapping)
          results << result unless results.any? { |r| r[:id] == result[:id] }
          break if results.size >= limit
        end
        return results if results.any?
      end

      # Search by city name (case-insensitive, partial match)
      city_matches = AddressGeographicMapping.where("LOWER(city) LIKE ?", "%#{query.downcase}%")
      city_matches = filter_by_states(city_matches)
      city_matches.limit(limit).each do |mapping|
        result = format_address_result(mapping)
        results << result unless results.any? { |r| r[:id] == result[:id] }
        break if results.size >= limit
      end

      # Search by county name if we haven't reached the limit
      if results.size < limit
        county_matches = AddressGeographicMapping.where("LOWER(county) LIKE ?", "%#{query.downcase}%")
        county_matches = filter_by_states(county_matches)
        county_matches.limit(limit - results.size).each do |mapping|
          result = format_address_result(mapping)
          results << result unless results.any? { |r| r[:id] == result[:id] }
          break if results.size >= limit
        end
      end

      results
    end

    private

    def filter_by_states(query)
      return query if @selected_states.blank?
      query.where(state: @selected_states)
    end

    def format_address_result(address_mapping)
      {
        id: address_mapping.id,
        name: "#{address_mapping.city}, #{address_mapping.state} #{address_mapping.zip_code}",
        city: address_mapping.city,
        state: address_mapping.state,
        zip_code: address_mapping.zip_code,
        county: address_mapping.county,
        type: "ADDRESS",
        status: "ENABLED"
      }
    end

    def format_result(geo_target)
      {
        id: geo_target.resource_name,
        name: geo_target.name,
        type: geo_target.target_type,
        status: "ENABLED"
      }
    end
  end
end

