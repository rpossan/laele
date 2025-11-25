class MakeLoginCustomerIdNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :google_accounts, :login_customer_id, true
  end
end

