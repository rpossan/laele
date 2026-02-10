FactoryBot.define do
  factory :geo_target do
    sequence(:criteria_id) { |n| "#{1000000 + n}" }
    sequence(:name) { |n| "Location#{n}" }
    canonical_name { "#{name},State,Country" }
    country_code { 'US' }
    target_type { 'City' }
  end
end
