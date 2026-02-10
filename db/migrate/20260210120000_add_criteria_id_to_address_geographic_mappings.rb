class AddCriteriaIdToAddressGeographicMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :address_geographic_mappings, :criteria_id, :string
    add_index :address_geographic_mappings, :criteria_id, unique: true
  end
end
