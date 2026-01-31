class CreateAddressGeographicMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :address_geographic_mappings do |t|
      t.string :zip_code, null: false
      t.string :city, null: false
      t.string :county, null: false
      t.string :state, null: false
      t.string :country_code, null: false, default: "US"

      t.timestamps
    end

    # Add indexes for fast lookups
    add_index :address_geographic_mappings, :zip_code
    add_index :address_geographic_mappings, [:city, :state]
    add_index :address_geographic_mappings, [:county, :state]
    add_index :address_geographic_mappings, :state
    add_index :address_geographic_mappings, [:zip_code, :city, :county, :country_code], unique: true, name: "index_agm_on_zip_city_county_country"
  end
end
