module GoogleAds
  class OfflineGeoLookup
    def initialize(country_code: nil)
      @country_code = country_code
    end

    def find(query)
      return [] if query.blank?

      query = query.strip
      results = []

      # Exact match on criteria_id
      if query.match?(/^\d+$/)
        geo_target = GeoTarget.find_by(criteria_id: query)
        if geo_target
          results << format_result(geo_target)
        end
      end

      # Exact match on name (case-insensitive)
      exact_name_matches = GeoTarget.where("LOWER(name) = ?", query.downcase)
      exact_name_matches = exact_name_matches.by_country(@country_code) if @country_code.present?
      exact_name_matches.each do |geo_target|
        result = format_result(geo_target)
        results << result unless results.any? { |r| r[:id] == result[:id] }
      end

      # Exact match on canonical_name (case-insensitive)
      exact_canonical_matches = GeoTarget.where("LOWER(canonical_name) = ?", query.downcase)
      exact_canonical_matches = exact_canonical_matches.by_country(@country_code) if @country_code.present?
      exact_canonical_matches.each do |geo_target|
        result = format_result(geo_target)
        results << result unless results.any? { |r| r[:id] == result[:id] }
      end

      results
    end

    def search(query, limit: 20)
      return [] if query.blank?

      query = query.strip
      return [] if query.length < 2

      results = []

      # Search in name (case-insensitive, partial match)
      name_matches = GeoTarget.where("LOWER(name) LIKE ?", "%#{query.downcase}%")
      name_matches = name_matches.by_country(@country_code) if @country_code.present?
      name_matches.limit(limit).each do |geo_target|
        result = format_result(geo_target)
        results << result unless results.any? { |r| r[:id] == result[:id] }
        break if results.size >= limit
      end

      # Search in canonical_name if we haven't reached the limit
      if results.size < limit
        canonical_matches = GeoTarget.where("LOWER(canonical_name) LIKE ?", "%#{query.downcase}%")
        canonical_matches = canonical_matches.by_country(@country_code) if @country_code.present?
        canonical_matches.limit(limit - results.size).each do |geo_target|
          result = format_result(geo_target)
          results << result unless results.any? { |r| r[:id] == result[:id] }
          break if results.size >= limit
        end
      end

      results
    end

    private

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

