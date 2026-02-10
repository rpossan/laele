FactoryBot.define do
  factory :address_geographic_mapping do
    zip_code { Faker::Address.zip_code }
    city { Faker::Address.city }
    county { Faker::Address.country }
    state { Faker::Address.state }
    country_code { Faker::Address.country_code }
  end
end
