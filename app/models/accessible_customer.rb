class AccessibleCustomer < ApplicationRecord
  belongs_to :google_account

  validates :customer_id, presence: true

  scope :ordered, -> { order(:display_name) }
end

