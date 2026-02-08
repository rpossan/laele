namespace :geographic do
  def state_name_to_code(state_name)
    state_map = {
      "Alabama" => "AL", "Alaska" => "AK", "Arizona" => "AZ", "Arkansas" => "AR",
      "California" => "CA", "Colorado" => "CO", "Connecticut" => "CT", "Delaware" => "DE",
      "Florida" => "FL", "Georgia" => "GA", "Hawaii" => "HI", "Idaho" => "ID",
      "Illinois" => "IL", "Indiana" => "IN", "Iowa" => "IA", "Kansas" => "KS",
      "Kentucky" => "KY", "Louisiana" => "LA", "Maine" => "ME", "Maryland" => "MD",
      "Massachusetts" => "MA", "Michigan" => "MI", "Minnesota" => "MN", "Mississippi" => "MS",
      "Missouri" => "MO", "Montana" => "MT", "Nebraska" => "NE", "Nevada" => "NV",
      "New Hampshire" => "NH", "New Jersey" => "NJ", "New Mexico" => "NM", "New York" => "NY",
      "North Carolina" => "NC", "North Dakota" => "ND", "Ohio" => "OH", "Oklahoma" => "OK",
      "Oregon" => "OR", "Pennsylvania" => "PA", "Rhode Island" => "RI", "South Carolina" => "SC",
      "South Dakota" => "SD", "Tennessee" => "TN", "Texas" => "TX", "Utah" => "UT",
      "Vermont" => "VT", "Virginia" => "VA", "Washington" => "WA", "West Virginia" => "WV",
      "Wisconsin" => "WI", "Wyoming" => "WY", "District of Columbia" => "DC"
    }
    state_map[state_name]
  end

  desc "Import geographic data from geo_targets.csv (Google Ads geo-targeting data)"
  task import: :environment do
    file_path = ENV.fetch("FILE", "geo_targets.csv")

    unless File.exist?(file_path)
      puts "Error: File not found: #{file_path}"
      puts "Usage: rake geographic:import FILE=path/to/geo_targets.csv"
      puts ""
      puts "Expected CSV format (Google Ads geo-targeting data with headers):"
      puts "  Criteria ID,Name,Canonical Name,Parent ID,Country Code,Target Type"
      puts ""
      puts "Example:"
      puts "  1012927,Abbeville,\"Abbeville,Alabama,United States\",21133,US,City"
      puts "  1012965,Calhoun County,\"Calhoun County,Alabama,United States\",21133,US,County"
      exit 1
    end

    puts "Importing geographic data from #{file_path}..."

    require "csv"

    total_rows = 0
    imported = 0
    updated = 0
    skipped = 0
    errors = 0
    skip_reasons = Hash.new(0)

    CSV.foreach(file_path, headers: true) do |row|
      total_rows += 1

      begin
        name = row["Name"]&.strip
        canonical_name = row["Canonical Name"]&.strip
        country_code = row["Country Code"]&.strip || "US"
        target_type = row["Target Type"]&.strip

        # Skip if no canonical name
        unless canonical_name.present?
          skipped += 1
          skip_reasons["no_canonical_name"] += 1
          next
        end

        # Parse canonical name format: "City/County,State,Country"
        # Example: "Abbeville,Alabama,United States"
        parts = canonical_name.split(",").map(&:strip)
        unless parts.size >= 2
          skipped += 1
          skip_reasons["invalid_canonical_format"] += 1
          next
        end

        location_name = parts[0]
        state_name = parts[1]
        
        # Convert state name to state code (e.g., "Alabama" -> "AL")
        state = state_name_to_code(state_name)
        
        # Skip if we couldn't determine the state code
        unless state.present?
          skipped += 1
          skip_reasons["unknown_state_#{state_name}"] += 1
          next
        end

        # Only process City and County types
        unless target_type == "City" || target_type == "County"
          skipped += 1
          skip_reasons["invalid_target_type_#{target_type}"] += 1
          next
        end

        # For cities and counties, we create entries with placeholder zip codes
        # This allows us to map city/county to state for validation purposes
        if target_type == "City"
          city = location_name
          county = location_name  # Use city name as county placeholder
          # Create a pseudo zip code based on state and city
          zip_code = "#{state}#{city.parameterize[0..6]}".ljust(5, "0")[0..4]
        elsif target_type == "County"
          city = location_name
          county = location_name
          # Create a pseudo zip code based on state and county
          zip_code = "#{state}#{location_name.parameterize[0..6]}".ljust(5, "1")[0..4]
        end

        # Find or initialize the record
        mapping = AddressGeographicMapping.find_or_initialize_by(
          zip_code: zip_code,
          city: city,
          county: county,
          country_code: country_code
        )

        is_new = mapping.new_record?

        # Assign attributes
        mapping.assign_attributes(
          state: state,
          country_code: country_code
        )

        if mapping.save
          if is_new
            imported += 1
          else
            updated += 1
          end
        else
          puts "Error saving row #{total_rows} (#{location_name}, #{state}): #{mapping.errors.full_messages.join(', ')}"
          errors += 1
        end

        if total_rows % 5000 == 0
          puts "Processed #{total_rows} rows... (imported: #{imported}, updated: #{updated}, skipped: #{skipped}, errors: #{errors})"
        end
      rescue => e
        puts "Error processing row #{total_rows}: #{e.message}"
        errors += 1
      end
    end

    puts "\nImport completed!"
    puts "Total rows processed: #{total_rows}"
    puts "New records imported: #{imported}"
    puts "Existing records updated: #{updated}"
    puts "Rows skipped: #{skipped}"
    puts "Errors: #{errors}"
    
    if skip_reasons.any?
      puts "\nSkip reasons:"
      skip_reasons.sort_by { |_, count| -count }.each do |reason, count|
        puts "  #{reason}: #{count}"
      end
    end
  end

  desc "Import geographic data (Zip Code -> City -> County -> State) from CSV file for United States"
  task import_from_csv: :environment do
    file_path = ENV.fetch("FILE", "geographic_data.csv")

    unless File.exist?(file_path)
      puts "Error: File not found: #{file_path}"
      puts "Usage: rake geographic:import_from_csv FILE=path/to/geographic_data.csv"
      puts ""
      puts "Expected CSV format (with headers):"
      puts "  zip_code,city,county,state"
      puts ""
      puts "Example:"
      puts "  90210,Beverly Hills,Los Angeles,CA"
      puts "  10001,New York,New York,NY"
      exit 1
    end

    puts "Importing geographic data from #{file_path}..."

    require "csv"

    total_rows = 0
    imported = 0
    updated = 0
    skipped = 0
    errors = 0

    CSV.foreach(file_path, headers: true) do |row|
      total_rows += 1

      begin
        zip_code = row["zip_code"]&.strip
        city = row["city"]&.strip
        county = row["county"]&.strip
        state = row["state"]&.strip

        # Validate required fields
        unless zip_code.present? && city.present? && county.present? && state.present?
          puts "Warning: Skipping row #{total_rows} - missing required fields (zip_code, city, county, state)"
          skipped += 1
          next
        end

        # Normalize state code to uppercase
        state = state.upcase

        # Find or initialize the record (always US)
        mapping = AddressGeographicMapping.find_or_initialize_by(
          zip_code: zip_code,
          city: city,
          county: county,
          country_code: "US"
        )

        is_new = mapping.new_record?

        # Assign attributes
        mapping.assign_attributes(
          state: state,
          country_code: "US"
        )

        if mapping.save
          if is_new
            imported += 1
          else
            updated += 1
          end
        else
          puts "Error saving row #{total_rows} (#{zip_code}, #{city}, #{county}): #{mapping.errors.full_messages.join(', ')}"
          errors += 1
        end

        if total_rows % 1000 == 0
          puts "Processed #{total_rows} rows... (imported: #{imported}, updated: #{updated}, skipped: #{skipped}, errors: #{errors})"
        end
      rescue => e
        puts "Error processing row #{total_rows}: #{e.message}"
        errors += 1
      end
    end

    puts "\nImport completed!"
    puts "Total rows processed: #{total_rows}"
    puts "New records imported: #{imported}"
    puts "Existing records updated: #{updated}"
    puts "Rows skipped: #{skipped}"
    puts "Errors: #{errors}"
  end

  desc "Clear all geographic data from the database"
  task clear: :environment do
    puts "Clearing all geographic data..."
    count = AddressGeographicMapping.delete_all
    puts "Deleted #{count} records."
  end

  desc "Show statistics about geographic data"
  task stats: :environment do
    total = AddressGeographicMapping.count
    states = AddressGeographicMapping.distinct.pluck(:state).sort
    countries = AddressGeographicMapping.distinct.pluck(:country_code).sort

    puts "Geographic Data Statistics"
    puts "=" * 50
    puts "Total records: #{total}"
    puts "States: #{states.join(', ')}"
    puts "Countries: #{countries.join(', ')}"
    puts ""

    if states.any?
      puts "Records by state:"
      AddressGeographicMapping.group(:state).count.sort_by { |_, count| -count }.each do |state, count|
        puts "  #{state}: #{count}"
      end
    end
  end

  desc "Validate geographic data integrity"
  task validate: :environment do
    puts "Validating geographic data..."

    issues = []

    # Check for missing required fields
    missing_fields = AddressGeographicMapping.where(
      "zip_code IS NULL OR city IS NULL OR county IS NULL OR state IS NULL OR country_code IS NULL"
    ).count

    if missing_fields > 0
      issues << "Found #{missing_fields} records with missing required fields"
    end

    # Check for invalid state codes (should be 2 characters for US states)
    invalid_states = AddressGeographicMapping.where("LENGTH(state) != 2").count

    if invalid_states > 0
      issues << "Found #{invalid_states} records with invalid state codes (expected 2 characters)"
    end

    # Check for duplicate entries
    duplicates = AddressGeographicMapping.group(:zip_code, :city, :county, :country_code)
                                         .having("COUNT(*) > 1")
                                         .count

    if duplicates.any?
      issues << "Found #{duplicates.size} duplicate entries"
    end

    if issues.empty?
      puts "✓ All geographic data is valid!"
    else
      puts "✗ Issues found:"
      issues.each { |issue| puts "  - #{issue}" }
    end
  end
end
