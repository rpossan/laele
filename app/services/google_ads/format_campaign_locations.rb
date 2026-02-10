module GoogleAds
  class FormatCampaignLocations
    def initialize(existing_targets)
      @existing_targets = existing_targets
    end

    def call
      @existing_targets.map { |target| format_location(target) }
    end

    private

    def format_location(target)
      geo_target_constant = target[:geo_target_constant]
      
      return format_unknown_location(target) unless geo_target_constant.present?

      criteria_id = extract_criteria_id(geo_target_constant)
      location_data = fetch_location_data(criteria_id)

      {
        resource_name: target[:resource_name],
        geo_target_constant: geo_target_constant,
        name: location_data[:name],
        criteria_id: criteria_id,
        state: location_data[:state]
      }
    end

    def extract_criteria_id(geo_target_constant)
      geo_target_constant.split('/').last
    end

    def fetch_location_data(criteria_id)
      address_mapping = AddressGeographicMapping.find_by(criteria_id: criteria_id)
      
      if address_mapping
        {
          name: "#{address_mapping.city} (#{address_mapping.state})",
          state: address_mapping.state
        }
      else
        geo_target = GeoTarget.find_by(criteria_id: criteria_id)
        {
          name: geo_target&.name || "geoTargetConstants/#{criteria_id}",
          state: nil
        }
      end
    end

    def format_unknown_location(target)
      {
        resource_name: target[:resource_name],
        geo_target_constant: nil,
        name: 'Unknown',
        criteria_id: nil,
        state: nil
      }
    end
  end
end
