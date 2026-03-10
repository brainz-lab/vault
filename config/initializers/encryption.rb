# Vault Encryption Configuration
# Initializes the master key for encrypting data encryption keys (DEKs)

Rails.application.configure do
  # The master key is used to encrypt per-project data encryption keys
  # In production, this should be a strong 32+ character key
  config.vault_master_key = ENV.fetch("VAULT_MASTER_KEY") do
    if ENV["SECRET_KEY_BASE_DUMMY"]
      # Asset precompilation — dummy key is fine
      "bl_vault_master_dev_key_32chars!"
    elsif Rails.env.test?
      # Test environment — use deterministic key
      "bl_vault_master_test_key_32ch!"
    elsif Rails.env.production?
      raise "VAULT_MASTER_KEY environment variable must be set in production"
    else
      raise "VAULT_MASTER_KEY environment variable must be set. Add it to .env.native or .env"
    end
  end
end
