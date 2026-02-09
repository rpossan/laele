class AddStripeFields < ActiveRecord::Migration[8.0]
  def change
    # Add stripe_price_id to plans (for BRL and USD)
    add_column :plans, :stripe_price_id_brl, :string
    add_column :plans, :stripe_price_id_usd, :string

    # Add stripe fields to user_subscriptions
    add_column :user_subscriptions, :stripe_customer_id, :string
    add_column :user_subscriptions, :stripe_subscription_id, :string

    # Add indexes
    add_index :plans, :stripe_price_id_brl
    add_index :plans, :stripe_price_id_usd
    add_index :user_subscriptions, :stripe_customer_id
    add_index :user_subscriptions, :stripe_subscription_id
  end
end
