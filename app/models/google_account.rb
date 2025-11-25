class GoogleAccount < ApplicationRecord
  belongs_to :user

  has_many :accessible_customers, dependent: :destroy
  has_one :active_customer_selection, dependent: :destroy

  validates :refresh_token, presence: true

  # Plain text refresh token for now (encrypt later)

  def login_customer_id_formatted
    login_customer_id.to_s.gsub(/\D/, "").chars.each_slice(3).map(&:join).join("-")
  end

  def access_token_cache_key
    "google_ads/access_token/#{id}"
  end
end
