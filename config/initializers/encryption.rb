# Configure Rails encryption
# For development, we'll use a simple configuration
# In production, use RAILS_MASTER_KEY environment variable or config/master.key

if Rails.env.development?
  # Use fixed keys for development (NOT for production!)
  # Rails encryption needs 32-byte keys (64 hex characters)
  dev_key = "94e07481d385f8637b296200d68be934" * 2 # 64 hex chars = 32 bytes
  
  Rails.application.config.active_record.encryption.primary_key = dev_key
  Rails.application.config.active_record.encryption.deterministic_key = dev_key
  Rails.application.config.active_record.encryption.key_derivation_salt = dev_key
else
  # In production, use environment variables or credentials
  Rails.application.config.active_record.encryption.primary_key = ENV.fetch("RAILS_MASTER_KEY") do
    Rails.application.credentials.dig(:secret_key_base) || raise("RAILS_MASTER_KEY or secret_key_base must be set in production")
  end
  
  Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("RAILS_ENCRYPTION_DETERMINISTIC_KEY") do
    Rails.application.credentials.dig(:secret_key_base) || raise("RAILS_ENCRYPTION_DETERMINISTIC_KEY or secret_key_base must be set in production")
  end
  
  Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("RAILS_ENCRYPTION_KEY_DERIVATION_SALT") do
    Rails.application.credentials.dig(:secret_key_base) || raise("RAILS_ENCRYPTION_KEY_DERIVATION_SALT or secret_key_base must be set in production")
  end
end

