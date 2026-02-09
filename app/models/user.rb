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

  def active_customer_id
    active_customer_selection&.customer_id
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
end
