namespace :geo do
  desc "Import geo targets from CSV file"
  task import: :environment do
    file_path = ENV.fetch("FILE", "geo_targets.csv")

    unless File.exist?(file_path)
      puts "Error: File not found: #{file_path}"
      puts "Usage: rake geo:import FILE=path/to/GeoTargetConstants.csv"
      exit 1
    end

    puts "Importing geo targets from #{file_path}..."

    require "csv"

    total_rows = 0
    imported = 0
    updated = 0
    errors = 0

    GeoTarget.delete_all
    puts "Cleared existing geo targets."

    CSV.foreach(file_path, headers: true) do |row|
      total_rows += 1

      begin
        criteria_id = row["Criteria ID"]&.strip
        name = row["Name"]&.strip
        canonical_name = row["Canonical Name"]&.strip
        parent_id = row["Parent ID"]&.strip
        country_code = row["Country Code"]&.strip
        target_type = row["Target Type"]&.strip

        unless criteria_id.present?
          puts "Warning: Skipping row #{total_rows} - missing Criteria ID"
          errors += 1
          next
        end

        geo_target = GeoTarget.find_or_initialize_by(criteria_id: criteria_id)
        is_new = geo_target.new_record?

        geo_target.assign_attributes(
          name: name,
          canonical_name: canonical_name,
          parent_id: parent_id.presence,
          country_code: country_code,
          target_type: target_type
        )

        if geo_target.save
          if is_new
            imported += 1
          else
            updated += 1
          end
        else
          puts "Error saving row #{total_rows} (Criteria ID: #{criteria_id}): #{geo_target.errors.full_messages.join(', ')}"
          errors += 1
        end

        if total_rows % 1000 == 0
          puts "Processed #{total_rows} rows... (imported: #{imported}, updated: #{updated}, errors: #{errors})"
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
    puts "Errors: #{errors}"
  end
end
