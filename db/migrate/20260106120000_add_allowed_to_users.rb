class AddAllowedToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :allowed, :boolean, default: false, null: false
    add_index :users, :allowed
  end
end
