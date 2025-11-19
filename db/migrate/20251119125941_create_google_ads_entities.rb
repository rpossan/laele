class CreateGoogleAdsEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :google_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :login_customer_id, null: false
      t.string :refresh_token_ciphertext, null: false
      t.text :scopes, array: true, default: []
      t.datetime :last_synced_at
      t.string :status, default: "active", null: false

      t.timestamps
    end
    add_index :google_accounts, [:user_id, :login_customer_id], unique: true

    create_table :accessible_customers do |t|
      t.references :google_account, null: false, foreign_key: true
      t.string :customer_id, null: false
      t.string :display_name
      t.string :currency_code
      t.string :role

      t.timestamps
    end
    add_index :accessible_customers, [:google_account_id, :customer_id], unique: true, name: "index_accessible_customers_on_account_and_customer"

    create_table :active_customer_selections do |t|
      t.references :user, null: false, foreign_key: true,
                          index: { unique: true, name: "index_active_customer_selections_on_user_id_unique" }
      t.references :google_account, null: false, foreign_key: true
      t.string :customer_id, null: false

      t.timestamps
    end
  end
end
