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

  def access_token_cache_key
    "google_ads/access_token/#{id}"
  end

  # Returns customers based on user's plan
  # For allowed users: all customers (MVP/admin bypass)
  # For unlimited plan: all customers
  # For limited/per-account plans: only active customers
  def plan_accessible_customers
    # Users with allowed: true get full access to all accounts
    return accessible_customers if user.allowed?

    subscription = user.user_subscription
    if subscription&.plan&.unlimited? && subscription.plan.max_accounts.nil?
      accessible_customers
    else
      active_accessible_customers
    end
  end
end
