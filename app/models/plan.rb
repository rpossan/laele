class Plan < ApplicationRecord
  has_many :user_subscriptions, dependent: :restrict_with_error

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
  validates :pricing_type, presence: true, inclusion: { in: %w[per_account fixed] }
  validates :price_cents_brl, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :price_cents_usd, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_accounts, numericality: { greater_than: 0, allow_nil: true }
  validates :price_per_account_cents_brl, presence: true, if: :per_account?
  validates :price_per_account_cents_usd, presence: true, if: :per_account?

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc) }
  scope :recommended, -> { where(recommended: true) }

  def per_account?
    pricing_type == "per_account"
  end

  def fixed?
    pricing_type == "fixed"
  end

  def unlimited?
    max_accounts.nil?
  end

  def price_brl
    price_cents_brl / 100.0
  end

  def price_usd
    price_cents_usd / 100.0
  end

  def price_per_account_brl
    return nil unless per_account?
    price_per_account_cents_brl / 100.0
  end

  def price_per_account_usd
    return nil unless per_account?
    price_per_account_cents_usd / 100.0
  end

  def calculate_price_brl(accounts_count)
    if per_account?
      accounts_count * price_per_account_cents_brl
    else
      price_cents_brl
    end
  end

  def calculate_price_usd(accounts_count)
    if per_account?
      accounts_count * price_per_account_cents_usd
    else
      price_cents_usd
    end
  end

  def allows_accounts_count?(count)
    return true if unlimited?
    count <= max_accounts
  end

  # Human-readable price display
  def display_price_brl(accounts_count = nil)
    if per_account?
      "R$ #{format('%.2f', price_per_account_brl)} por subconta"
    else
      "R$ #{format('%.2f', price_brl)}"
    end
  end

  def display_price_usd(accounts_count = nil)
    if per_account?
      "USD #{format('%.2f', price_per_account_usd)} per account"
    else
      "USD #{format('%.2f', price_usd)}"
    end
  end
end
