class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.string :pricing_type, null: false # 'per_account', 'fixed'
      t.integer :price_cents_brl, null: false
      t.integer :price_cents_usd, null: false
      t.integer :max_accounts # null means unlimited
      t.integer :price_per_account_cents_brl # only for 'per_account' type
      t.integer :price_per_account_cents_usd # only for 'per_account' type
      t.boolean :recommended, default: false, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :plans, :slug, unique: true
    add_index :plans, :active
    add_index :plans, :position
  end
end
