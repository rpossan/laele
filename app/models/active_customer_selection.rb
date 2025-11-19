class ActiveCustomerSelection < ApplicationRecord
  belongs_to :user
  belongs_to :google_account

  validates :customer_id, presence: true
  validates :user_id, uniqueness: true
end

