# Configure Rails encryption
# For development, we'll use a simple configuration
# In production, use RAILS_MASTER_KEY environment variable or config/master.key

# Check if we're in asset precompilation context
# During assets:precompile, we don't need real encryption keys
is_asset_precompile = ENV["SECRET_KEY_BASE"] == "dummy_secret_key_base_for_build_only" ||
                      (defined?(Rake) && Rake.application.top_level_tasks.any? { |task| task.include?("assets:precompile") })

if is_asset_precompile
  # Use dummy keys during asset precompilation - they won't be used
  dummy_key = "0" * 64 # 64 hex chars = 32 bytes
  Rails.application.config.active_record.encryption.primary_key = dummy_key
  Rails.application.config.active_record.encryption.deterministic_key = dummy_key
  Rails.application.config.active_record.encryption.key_derivation_salt = dummy_key
elsif Rails.env.development? || Rails.env.test?
  # Use fixed keys for development and test (NOT for production!)
  # Rails encryption needs 32-byte keys (64 hex characters)
  dev_key = "94e07481d385f8637b296200d68be934" * 2 # 64 hex chars = 32 bytes
  
  Rails.application.config.active_record.encryption.primary_key = dev_key
  Rails.application.config.active_record.encryption.deterministic_key = dev_key
  Rails.application.config.active_record.encryption.key_derivation_salt = dev_key
else
  # In production, use environment variables or credentials
  primary_key = ENV["RAILS_MASTER_KEY"] || Rails.application.credentials.dig(:secret_key_base)
  if primary_key.nil? || primary_key.empty?
    raise("RAILS_MASTER_KEY or secret_key_base must be set in production")
  end
  Rails.application.config.active_record.encryption.primary_key = primary_key
  
  deterministic_key = ENV["RAILS_ENCRYPTION_DETERMINISTIC_KEY"] || Rails.application.credentials.dig(:secret_key_base)
  if deterministic_key.nil? || deterministic_key.empty?
    raise("RAILS_ENCRYPTION_DETERMINISTIC_KEY or secret_key_base must be set in production")
  end
  Rails.application.config.active_record.encryption.deterministic_key = deterministic_key
  
  key_derivation_salt = ENV["RAILS_ENCRYPTION_KEY_DERIVATION_SALT"] || Rails.application.credentials.dig(:secret_key_base)
  if key_derivation_salt.nil? || key_derivation_salt.empty?
    raise("RAILS_ENCRYPTION_KEY_DERIVATION_SALT or secret_key_base must be set in production")
  end
  Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
end

