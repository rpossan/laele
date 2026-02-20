class RevampPlansWithStripePaymentLinks < ActiveRecord::Migration[8.0]
  def up
    # Add stripe_payment_link column to plans
    add_column :plans, :stripe_payment_link, :string unless column_exists?(:plans, :stripe_payment_link)

    # Deactivate old plans (keep them for existing subscribers)
    execute <<-SQL.squish
      UPDATE plans SET active = false WHERE slug IN ('per_account', 'unlimited_30', 'unlimited')
    SQL

    # Insert new plans based on sub-account limits
    # Plan 1: 1 Sub-Account - R$50
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, stripe_payment_link, created_at, updated_at)
      VALUES ('sub_1', '1 Sub-Account', '1 subconta LSA Escale', 'fixed', 5000, 1000, 1, NULL, NULL, false, true, 1, 'https://buy.stripe.com/28E14neP5emlaB8cUBgbm00', NOW(), NOW())
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price_cents_brl = EXCLUDED.price_cents_brl,
        price_cents_usd = EXCLUDED.price_cents_usd,
        max_accounts = EXCLUDED.max_accounts,
        price_per_account_cents_brl = EXCLUDED.price_per_account_cents_brl,
        price_per_account_cents_usd = EXCLUDED.price_per_account_cents_usd,
        recommended = EXCLUDED.recommended,
        active = EXCLUDED.active,
        position = EXCLUDED.position,
        stripe_payment_link = EXCLUDED.stripe_payment_link,
        updated_at = NOW()
    SQL

    # Plan 2: 3 Sub-Accounts - R$150
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, stripe_payment_link, created_at, updated_at)
      VALUES ('sub_3', '3 Sub-Accounts', '3 subcontas LSA Escale', 'fixed', 15000, 3000, 3, NULL, NULL, false, true, 2, 'https://buy.stripe.com/aFa9ATgXd4LL5gO2fXgbm01', NOW(), NOW())
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price_cents_brl = EXCLUDED.price_cents_brl,
        price_cents_usd = EXCLUDED.price_cents_usd,
        max_accounts = EXCLUDED.max_accounts,
        price_per_account_cents_brl = EXCLUDED.price_per_account_cents_brl,
        price_per_account_cents_usd = EXCLUDED.price_per_account_cents_usd,
        recommended = EXCLUDED.recommended,
        active = EXCLUDED.active,
        position = EXCLUDED.position,
        stripe_payment_link = EXCLUDED.stripe_payment_link,
        updated_at = NOW()
    SQL

    # Plan 3: 5 Sub-Accounts - R$250 (RECOMMENDED)
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, stripe_payment_link, created_at, updated_at)
      VALUES ('sub_5', '5 Sub-Accounts', '5 subcontas LSA Escale', 'fixed', 25000, 5000, 5, NULL, NULL, true, true, 3, 'https://buy.stripe.com/4gM7sLeP54LL8t08Elgbm02', NOW(), NOW())
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price_cents_brl = EXCLUDED.price_cents_brl,
        price_cents_usd = EXCLUDED.price_cents_usd,
        max_accounts = EXCLUDED.max_accounts,
        price_per_account_cents_brl = EXCLUDED.price_per_account_cents_brl,
        price_per_account_cents_usd = EXCLUDED.price_per_account_cents_usd,
        recommended = EXCLUDED.recommended,
        active = EXCLUDED.active,
        position = EXCLUDED.position,
        stripe_payment_link = EXCLUDED.stripe_payment_link,
        updated_at = NOW()
    SQL

    # Plan 4: 30-49 Sub-Accounts - R$1,000
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, stripe_payment_link, created_at, updated_at)
      VALUES ('sub_30', '30-49 Sub-Accounts', '30 a 49 subcontas LSA Escale', 'fixed', 100000, 20000, 49, NULL, NULL, false, true, 4, 'https://buy.stripe.com/28EaEXdL1cedgZwg6Ngbm03', NOW(), NOW())
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price_cents_brl = EXCLUDED.price_cents_brl,
        price_cents_usd = EXCLUDED.price_cents_usd,
        max_accounts = EXCLUDED.max_accounts,
        price_per_account_cents_brl = EXCLUDED.price_per_account_cents_brl,
        price_per_account_cents_usd = EXCLUDED.price_per_account_cents_usd,
        recommended = EXCLUDED.recommended,
        active = EXCLUDED.active,
        position = EXCLUDED.position,
        stripe_payment_link = EXCLUDED.stripe_payment_link,
        updated_at = NOW()
    SQL

    # Plan 5: 50/Unlimited Sub-Accounts - R$1,500
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, stripe_payment_link, created_at, updated_at)
      VALUES ('sub_unlimited', '50/Unlimited Sub-Accounts', 'Subcontas ilimitadas LSA Escale', 'fixed', 150000, 30000, NULL, NULL, NULL, false, true, 5, 'https://buy.stripe.com/00wfZh22jgut10y1bTgbm04', NOW(), NOW())
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        pricing_type = EXCLUDED.pricing_type,
        price_cents_brl = EXCLUDED.price_cents_brl,
        price_cents_usd = EXCLUDED.price_cents_usd,
        max_accounts = EXCLUDED.max_accounts,
        price_per_account_cents_brl = EXCLUDED.price_per_account_cents_brl,
        price_per_account_cents_usd = EXCLUDED.price_per_account_cents_usd,
        recommended = EXCLUDED.recommended,
        active = EXCLUDED.active,
        position = EXCLUDED.position,
        stripe_payment_link = EXCLUDED.stripe_payment_link,
        updated_at = NOW()
    SQL
  end

  def down
    # Remove new plans
    execute <<-SQL.squish
      DELETE FROM plans WHERE slug IN ('sub_1', 'sub_3', 'sub_5', 'sub_30', 'sub_unlimited')
    SQL

    # Re-activate old plans
    execute <<-SQL.squish
      UPDATE plans SET active = true WHERE slug IN ('per_account', 'unlimited_30', 'unlimited')
    SQL

    remove_column :plans, :stripe_payment_link if column_exists?(:plans, :stripe_payment_link)
  end
end
