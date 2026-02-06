class AddActiveToAccessibleCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :accessible_customers, :active, :boolean, default: false, null: false
    add_index :accessible_customers, :active
  end
end
