require "set"

module Lsa
  class ApplyGeoTargets
    def initialize(google_account:, customer_id:, campaign_id:)
      @google_account = google_account
      @customer_id = customer_id
      @campaign_id = campaign_id
    end

    def apply(location_names, country_code: nil)
      return { applied_geo_targets: [] } if location_names.blank?

      # Parse location names (can be comma-separated string, array of names, or array of resource names)
      location_array = if location_names.is_a?(String)
        location_names.split(",").map(&:strip).reject(&:blank?)
      else
        Array(location_names).map(&:to_s).map(&:strip).reject(&:blank?)
      end

      return { applied_geo_targets: [] } if location_array.empty?

      Rails.logger.info("[Lsa::ApplyGeoTargets] Applying geo targets for locations: #{location_array.inspect}")

      # Check if locations are already resource names (geoTargetConstants/...)
      # If they are, use them directly; otherwise, lookup using offline lookup
      found_targets = []
      
      location_array.each do |location_input|
        # Check if it's already a resource name
        if location_input.start_with?("geoTargetConstants/")
          found_targets << location_input
        else
          # Lookup using offline lookup
          lookup_service = GoogleAds::OfflineGeoLookup.new(country_code: country_code)
          results = lookup_service.find(location_input)
          if results.any?
            found_targets.concat(results.map { |r| r[:id] })
          else
            Rails.logger.warn("[Lsa::ApplyGeoTargets] No geo target found for: #{location_input}")
          end
        end
      end

      # Remove duplicates
      unique_targets = found_targets.uniq

      if unique_targets.empty?
        Rails.logger.warn("[Lsa::ApplyGeoTargets] No valid geo targets found for any location")
        return { applied_geo_targets: [] }
      end

      Rails.logger.info("[Lsa::ApplyGeoTargets] Found #{unique_targets.size} unique geo targets: #{unique_targets.inspect}")

      # Fetch existing targets
      get_service = GoogleAds::GetGeoTargets.new(
        google_account: @google_account,
        customer_id: @customer_id,
        campaign_id: @campaign_id
      )

      existing_targets = get_service.fetch_existing_targets
      existing_resource_names = existing_targets.map { |t| t[:resource_name] }
      existing_geo_target_constants = existing_targets.map { |t| t[:geo_target_constant] }.compact

      Rails.logger.info("[Lsa::ApplyGeoTargets] Found #{existing_resource_names.size} existing geo targets")

      # Extract criteria IDs from new targets (format: "geoTargetConstants/123456")
      new_criteria_ids = unique_targets.map { |t| t.split('/').last }.to_set

      # Find which existing targets should be removed (not in new list)
      targets_to_remove = existing_targets.select do |target|
        geo_target_constant = target[:geo_target_constant]
        next false unless geo_target_constant
        
        criteria_id = geo_target_constant.split('/').last
        !new_criteria_ids.include?(criteria_id)
      end.map { |t| t[:resource_name] }

      # Find which new targets need to be added (not already existing)
      targets_to_add = unique_targets.reject do |new_target|
        criteria_id = new_target.split('/').last
        existing_geo_target_constants.any? { |existing| existing.split('/').last == criteria_id }
      end

      Rails.logger.info("[Lsa::ApplyGeoTargets] Targets to add: #{targets_to_add.size}, Targets to remove: #{targets_to_remove.size}")

      # For LSA campaigns, we must maintain at least one location
      # Strategy: Add new targets first, then remove old ones
      # This ensures we never have zero locations

      added_count = 0
      removed_count = 0

      # Add new targets first
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

      # Remove old targets that are not in the new list
      # Only remove if we have new targets to ensure at least one location remains
      if targets_to_remove.any? && (targets_to_add.any? || unique_targets.any?)
        remove_service = GoogleAds::RemoveGeoTargets.new(
          google_account: @google_account,
          customer_id: @customer_id
        )
        removed_resource_names = remove_service.remove_targets(targets_to_remove)
        removed_count = removed_resource_names.size
        Rails.logger.info("[Lsa::ApplyGeoTargets] Removed #{removed_count} old geo targets")
      end

      {
        applied_geo_targets: unique_targets,
        added_count: added_count,
        removed_count: removed_count,
        total_count: unique_targets.size
      }
    rescue => e
      Rails.logger.error("[Lsa::ApplyGeoTargets] Error applying geo targets: #{e.class} - #{e.message}")
      Rails.logger.error("[Lsa::ApplyGeoTargets] Backtrace: #{e.backtrace.first(10).join("\n")}")
      raise e
    end

    private

    attr_reader :google_account, :customer_id, :campaign_id
  end
end

