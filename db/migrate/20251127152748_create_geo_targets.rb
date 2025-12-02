class CreateGeoTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :geo_targets do |t|
      t.string :criteria_id
      t.string :name
      t.string :canonical_name
      t.string :parent_id
      t.string :country_code
      t.string :target_type

      t.timestamps
    end

    add_index :geo_targets, :criteria_id, unique: true
    add_index :geo_targets, :name
    add_index :geo_targets, :canonical_name
    add_index :geo_targets, :country_code
    add_index :geo_targets, :target_type
  end
end
