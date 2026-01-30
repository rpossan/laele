class GoogleAccount < ApplicationRecord
  belongs_to :user

  has_many :accessible_customers, dependent: :destroy
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
end
