class AddressRecord
  attr_accessor :zip_code, :city, :county, :original_data

  def initialize(zip_code: nil, city: nil, county: nil, original_data: nil)
    @zip_code = zip_code
    @city = city
    @county = county
    @original_data = original_data
  end

  def complete?
    zip_code.present? || city.present? || county.present?
  end
end
