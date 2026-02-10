require "set"

module Lsa
  class ApplyGeoTargets
    def initialize(google_account:, customer_id:, campaign_id:)
      @google_account = google_account
      @customer_id = customer_id
      @campaign_id = campaign_id
    end

    def apply(location_names, country_code: nil, selected_states: nil, locations_to_remove: nil)
      # Handle locations to remove first
      removed_count = remove_locations(locations_to_remove) if locations_to_remove.present?

      return { applied_geo_targets: [], added_count: 0, removed_count: removed_count || 0, total_count: 0 } if location_names.blank?

      # Parse location names (can be comma-separated string, array of names, or array of resource names)
      location_array = if location_names.is_a?(String)
        location_names.split(",").map(&:strip).reject(&:blank?)
      else
        Array(location_names).map(&:to_s).map(&:strip).reject(&:blank?)
      end

      return { applied_geo_targets: [], added_count: 0, removed_count: removed_count || 0, total_count: 0 } if location_array.empty?

      Rails.logger.info("[Lsa::ApplyGeoTargets] Applying geo targets for locations: #{location_array.inspect}")
      Rails.logger.info("[Lsa::ApplyGeoTargets] Selected states: #{selected_states.inspect}")
      Rails.logger.info("[Lsa::ApplyGeoTargets] Locations to remove: #{locations_to_remove.inspect}")

      # Check if locations are already resource names (geoTargetConstants/...)
      # If they are, use them directly; otherwise, lookup using offline lookup
      found_targets = []
      
      location_array.each do |location_input|
        # Check if it's already a resource name
        if location_input.start_with?("geoTargetConstants/")
          found_targets << location_input
        else
          # Lookup using offline lookup with selected states filter
          lookup_service = GoogleAds::OfflineGeoLookup.new(country_code: country_code, selected_states: selected_states)
          results = lookup_service.find(location_input)
          if results.any?
            # Found in AddressGeographicMapping - can have multiple results for same city in different states
            results.each do |result|
              if result[:type] == "ADDRESS"
                # For addresses, the result[:id] is the database ID, we need to fetch the criteria_id
                begin
                  address_mapping = AddressGeographicMapping.find(result[:id])
                  if address_mapping.criteria_id.present?
                    found_targets << "geoTargetConstants/#{address_mapping.criteria_id}"
                  else
                    Rails.logger.warn("[Lsa::ApplyGeoTargets] No criteria_id found for address mapping ID: #{result[:id]}")
                  end
                rescue ActiveRecord::RecordNotFound
                  Rails.logger.warn("[Lsa::ApplyGeoTargets] Address mapping not found for ID: #{result[:id]}")
                end
              else
                found_targets << result[:id]
              end
            end
          else
            Rails.logger.warn("[Lsa::ApplyGeoTargets] No geo target found for: #{location_input}")
          end
        end
      end

      # Remove duplicates
      unique_targets = found_targets.uniq

      if unique_targets.empty?
        Rails.logger.warn("[Lsa::ApplyGeoTargets] No valid geo targets found for any location")
        return { applied_geo_targets: [], added_count: 0, removed_count: removed_count || 0, total_count: 0 }
      end

      Rails.logger.info("[Lsa::ApplyGeoTargets] Found #{unique_targets.size} unique geo targets: #{unique_targets.inspect}")

      # Fetch existing targets
      get_service = GoogleAds::GetGeoTargets.new(
        google_account: @google_account,
        customer_id: @customer_id,
        campaign_id: @campaign_id
      )

      existing_targets = get_service.fetch_existing_targets
      existing_geo_target_constants = existing_targets.map { |t| t[:geo_target_constant] }.compact

      Rails.logger.info("[Lsa::ApplyGeoTargets] Found #{existing_targets.size} existing geo targets")

      # Find which new targets need to be added (not already existing)
      targets_to_add = unique_targets.reject do |new_target|
        criteria_id = new_target.split('/').last
        existing_geo_target_constants.any? { |existing| existing.split('/').last == criteria_id }
      end

      Rails.logger.info("[Lsa::ApplyGeoTargets] Targets to add: #{targets_to_add.size}")

      added_count = 0

      # Add new targets
      if targets_to_add.any?
        create_service = GoogleAds::CreateLocationTarget.new(
          google_account: @google_account,
          customer_id: @customer_id,
          campaign_id: @campaign_id
        )
        applied_resource_names = create_service.add_location_targets(targets_to_add)
        added_count = applied_resource_names.size
        Rails.logger.info("[Lsa::ApplyGeoTargets] Added #{added_count} new geo targets")
      end

      # Calculate total count after additions and removals
      total_count = existing_targets.size + added_count - (removed_count || 0)

      {
        applied_geo_targets: unique_targets,
        added_count: added_count,
        removed_count: removed_count || 0,
        total_count: total_count
      }
    rescue => e
      Rails.logger.error("[Lsa::ApplyGeoTargets] Error applying geo targets: #{e.class} - #{e.message}")
      Rails.logger.error("[Lsa::ApplyGeoTargets] Backtrace: #{e.backtrace.first(10).join("\n")}")
      raise e
    end

    private

    attr_reader :google_account, :customer_id, :campaign_id

    def remove_locations(locations_to_remove)
      return 0 if locations_to_remove.blank?

      # locations_to_remove should be an array of resource names (e.g., "customers/123/campaignCriteria/456")
      resource_names_to_remove = Array(locations_to_remove).reject(&:blank?)

      return 0 if resource_names_to_remove.empty?

      remove_service = GoogleAds::RemoveGeoTargets.new(
        google_account: @google_account,
        customer_id: @customer_id
      )
      removed_resource_names = remove_service.remove_targets(resource_names_to_remove)
      Rails.logger.info("[Lsa::ApplyGeoTargets] Removed #{removed_resource_names.size} geo targets")
      
      removed_resource_names.size
    end
  end
end
