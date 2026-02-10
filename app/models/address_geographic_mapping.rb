class AddressGeographicMapping < ApplicationRecord
  validates :zip_code, :city, :county, :state, :country_code, presence: true
  validates :zip_code, uniqueness: { scope: [:city, :county, :country_code] }
  validates :criteria_id, uniqueness: true, allow_nil: true

  scope :by_state, ->(state) { where(state: state) }
  scope :by_zip_code, ->(zip) { where(zip_code: zip) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_county, ->(county) { where(county: county) }

  # Find state by address components (prioritizes zip_code for accuracy)
  def self.find_state(zip_code: nil, city: nil, county: nil)
    query = all
    query = query.by_zip_code(zip_code) if zip_code.present?
    query = query.by_city(city) if city.present?
    query = query.by_county(county) if county.present?
    query.pluck(:state).first
  end

  # Find all matching records
  def self.find_all_matches(zip_code: nil, city: nil, county: nil)
    query = all
    query = query.by_zip_code(zip_code) if zip_code.present?
    query = query.by_city(city) if city.present?
    query = query.by_county(county) if county.present?
    query
  end
end
