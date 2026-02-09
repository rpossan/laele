class SeedDefaultPlans < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:plans)

    # Plan 1: Per Account - R$50 per subaccount
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, created_at, updated_at)
      VALUES ('per_account', 'Por Subconta', 'Valor mensal calculado por número de subcontas', 'per_account', 0, 0, NULL, 5000, 1000, false, true, 1, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    SQL

    # Plan 2: Up to 30 accounts - R$1000 fixed
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, created_at, updated_at)
      VALUES ('unlimited_30', 'Ilimitado até 30', 'Até 30 subcontas por valor fixo mensal', 'fixed', 100000, 20000, 30, NULL, NULL, false, true, 2, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    SQL

    # Plan 3: Unlimited accounts - R$1500 fixed (RECOMMENDED)
    execute <<-SQL.squish
      INSERT INTO plans (slug, name, description, pricing_type, price_cents_brl, price_cents_usd, max_accounts, price_per_account_cents_brl, price_per_account_cents_usd, recommended, active, position, created_at, updated_at)
      VALUES ('unlimited', 'Ilimitado', 'Subcontas ilimitadas por valor fixo mensal', 'fixed', 150000, 30000, NULL, NULL, NULL, true, true, 3, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    SQL
  end

  def down
    return unless table_exists?(:plans)

    execute <<-SQL.squish
      DELETE FROM plans WHERE slug IN ('per_account', 'unlimited_30', 'unlimited')
    SQL
  end
end
