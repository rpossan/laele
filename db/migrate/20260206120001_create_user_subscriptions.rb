class CreateUserSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :plan, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false # pending, active, cancelled, expired
      t.integer :selected_accounts_count # number of accounts selected (for per_account plans)
      t.integer :calculated_price_cents_brl # calculated price at time of subscription
      t.integer :calculated_price_cents_usd
      t.datetime :started_at
      t.datetime :expires_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :user_subscriptions, :status
    add_index :user_subscriptions, :expires_at
  end
end
