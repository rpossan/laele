class UserSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :plan

  STATUSES = %w[pending active trialing cancelled canceled expired past_due unpaid].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :selected_accounts_count, presence: true, numericality: { greater_than: 0 }, if: -> { plan&.per_account? }
  validate :accounts_within_plan_limit

  before_save :calculate_prices, if: :should_calculate_prices?

  scope :pending, -> { where(status: "pending") }
  scope :active, -> { where(status: "active") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :expired, -> { where(status: "expired") }

  def pending?
    status == "pending"
  end

  def active?
    status == "active"
  end

  def cancelled?
    status == "cancelled"
  end

  def canceled?
    status == "canceled" || status == "cancelled"
  end

  def trialing?
    status == "trialing"
  end

  def past_due?
    status == "past_due"
  end

  def unpaid?
    status == "unpaid"
  end

  def expired?
    status == "expired"
  end

  def activate!
    update!(status: "active", started_at: Time.current)
  end

  def cancel!
    update!(status: "cancelled", cancelled_at: Time.current)
  end

  def expire!
    update!(status: "expired")
  end

  def calculated_price_brl
    stored_value = read_attribute(:calculated_price_cents_brl)
    if stored_value.present?
      stored_value / 100.0
    else
      plan.calculate_price_brl(selected_accounts_count || 0) / 100.0
    end
  end

  def calculated_price_usd
    stored_value = read_attribute(:calculated_price_cents_usd)
    if stored_value.present?
      stored_value / 100.0
    else
      plan.calculate_price_usd(selected_accounts_count || 0) / 100.0
    end
  end

  def display_price_brl
    "R$ #{format('%.2f', calculated_price_brl)}"
  end

  def display_price_usd
    "USD #{format('%.2f', calculated_price_usd)}"
  end

  private

  def accounts_within_plan_limit
    return unless plan && selected_accounts_count
    return if plan.allows_accounts_count?(selected_accounts_count)

    errors.add(:selected_accounts_count, "exceeds plan limit of #{plan.max_accounts} accounts")
  end

  def should_calculate_prices?
    plan_id_changed? || selected_accounts_count_changed?
  end

  def calculate_prices
    return unless plan

    self.calculated_price_cents_brl = plan.calculate_price_brl(selected_accounts_count || 0)
    self.calculated_price_cents_usd = plan.calculate_price_usd(selected_accounts_count || 0)
  end
end
