Rails.application.routes.default_url_options ||= {}

Rails.application.routes.default_url_options[:host] =
  ENV.fetch("APP_HOST", "localhost")

Rails.application.routes.default_url_options[:port] =
  ENV.fetch("APP_PORT", 3000)

Rails.application.routes.default_url_options[:protocol] =
  ENV.fetch("APP_PROTOCOL", "http")

