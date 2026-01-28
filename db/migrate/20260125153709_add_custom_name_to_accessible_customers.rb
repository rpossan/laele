class AddCustomNameToAccessibleCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :accessible_customers, :custom_name, :string
  end
end
