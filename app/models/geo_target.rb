class GeoTarget < ApplicationRecord
  validates :criteria_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :country_code, presence: true
  validates :target_type, presence: true

  scope :by_country, ->(code) { where(country_code: code) }
  scope :by_type, ->(type) { where(target_type: type) }

  def resource_name
    "geoTargetConstants/#{criteria_id}"
  end
end

