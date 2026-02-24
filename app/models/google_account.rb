class GoogleAccount < ApplicationRecord
  belongs_to :user

  has_many :accessible_customers, dependent: :destroy
  has_many :active_accessible_customers, -> { active }, class_name: "AccessibleCustomer"
  has_many :lead_feedback_submissions, dependent: :delete_all
  has_one :active_customer_selection, dependent: :destroy

  validates :refresh_token, presence: true

  # Plain text refresh token for now (encrypt later)

  def login_customer_id_formatted
    digits = login_customer_id.to_s
    "#{digits[0..2]}-#{digits[3..5]}-#{digits[6..-1]}"
  end

  def manager_customer_id_formatted
    digits = manager_customer_id.to_s
    "#{digits[0..2]}-#{digits[3..5]}-#{digits[6..-1]}"
  end

  def access_token_cache_key
    "google_ads/access_token/#{id}"
  end

  # Ensure manager_customer_id is set (should be set once and never change)
  def ensure_manager_customer_id!
    return if manager_customer_id.present?

    first_accessible = accessible_customers.first
    if first_accessible
      update!(manager_customer_id: first_accessible.customer_id)
    end
  end

  # Returns customers based on user's plan — STRICT enforcement
  # DB `active` column is the SINGLE SOURCE OF TRUTH for what's in the plan
  #
  # For unlimited plan or allowed (MVP) users: all customers
  # For limited plans: ONLY active customers (selected at plan selection time)
  def plan_accessible_customers
    subscription = user.user_subscription

    # Allowed (MVP) users without limited plan: all accounts
    if user.allowed? && !(subscription&.active? && subscription&.plan&.max_accounts.present?)
      return accessible_customers
    end

    # Active subscription with unlimited plan: all accounts
    if subscription&.active? && subscription&.plan&.unlimited?
      return accessible_customers
    end

    # Active subscription with limited plan: ONLY active accounts (DB truth)
    if subscription&.active? && subscription&.plan&.max_accounts.present?
      return active_accessible_customers
    end

    # No active subscription: only active accounts (shouldn't normally reach here)
    active_accessible_customers
  end
end
