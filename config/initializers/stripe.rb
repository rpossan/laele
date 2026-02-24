# Stripe configuration
Rails.application.config.to_prepare do
  Stripe.api_key = ENV["STRIPE_SECRET_KEY_2"]
end
