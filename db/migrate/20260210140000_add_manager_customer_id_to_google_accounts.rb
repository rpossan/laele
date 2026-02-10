class AddManagerCustomerIdToGoogleAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :google_accounts, :manager_customer_id, :string, comment: "The root manager account ID (should not change when switching between accessible customers)"
    
    # Add index for faster lookups
    add_index :google_accounts, :manager_customer_id
  end
end
