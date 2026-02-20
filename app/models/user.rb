class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :google_accounts, dependent: :destroy
  has_one :active_customer_selection, dependent: :destroy
  has_many :activity_logs, dependent: :destroy
  has_one :user_subscription, dependent: :destroy
  has_one :plan, through: :user_subscription

  scope :admins, -> { where(admin: true) }
  scope :non_admins, -> { where(admin: false) }
  scope :with_subscription, -> { joins(:user_subscription) }
  scope :without_subscription, -> { left_joins(:user_subscription).where(user_subscriptions: { id: nil }) }
  scope :recent, -> { order(created_at: :desc) }

  def active_customer_id
    active_customer_selection&.customer_id
  end

  def admin?
    admin == true
  end

  def subscribed?
    # Users with allowed: true bypass all subscription requirements (MVP/admin users)
    return true if allowed?

    user_subscription&.active?
  end

  def allowed?
    allowed == true
  end

  def has_pending_subscription?
    user_subscription&.pending?
  end

  def current_plan
    user_subscription&.plan
  end

  def subscription_status
    user_subscription&.status || "none"
  end

  def google_connected?
    google_accounts.any?
  end

  def total_accessible_customers
    google_accounts.joins(:accessible_customers).count
  end

  def active_accessible_customers_count
    google_accounts.joins(:active_accessible_customers).count
  end
end
