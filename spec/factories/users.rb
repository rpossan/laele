FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    password_confirmation { 'password123' }
    allowed { true }
  end
end


FactoryBot.define do
  factory :google_account do
    user
    sequence(:login_customer_id) { |n| (1000000000 + n).to_s }
    refresh_token_ciphertext { 'test_refresh_token_ciphertext' }
    refresh_token { 'test_refresh_token' }
    scopes { [] }
    status { 'active' }
  end
end

FactoryBot.define do
  factory :active_customer_selection do
    user
    google_account
    sequence(:customer_id) { |n| (1000000000 + n).to_s }
  end
end
