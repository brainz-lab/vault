# Vault Encryption Configuration
# Initializes the master key for encrypting data encryption keys (DEKs)

Rails.application.configure do
  # The master key is used to encrypt per-project data encryption keys
  # In production, this should be a strong 32+ character key
  config.vault_master_key = ENV.fetch("VAULT_MASTER_KEY") do
    if Rails.env.production?
      raise "VAULT_MASTER_KEY environment variable must be set in production"
    else
      # Development/test default (NOT SECURE - for development only)
      "bl_vault_master_dev_key_32chars!"
    end
  end
end
