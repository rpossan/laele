Rails.application.routes.default_url_options ||= {}
Rails.application.routes.default_url_options[:host] =
  ENV.fetch("APP_HOST", "localhost:3000")
Rails.application.routes.default_url_options[:protocol] =
  ENV.fetch("APP_PROTOCOL", "http")

