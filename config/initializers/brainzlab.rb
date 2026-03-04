# config/initializers/brainzlab.rb
#
# BrainzLab SDK - Observability & Monitoring
# Only configures if BRAINZLAB_SECRET_KEY is set.
# Uses BRAINZLAB_* prefixed env vars to avoid conflicts with
# Vault's own operational vars (VAULT_URL, VAULT_MASTER_KEY, etc.).
#
return unless ENV["BRAINZLAB_SECRET_KEY"]

BrainzLab.configure do |config|
  config.secret_key = ENV["BRAINZLAB_SECRET_KEY"]
  config.app_name   = ENV.fetch("BRAINZLAB_APP_NAME", "vault")

  # Core Observability (Layer 2)
  config.recall_url = ENV["BRAINZLAB_RECALL_URL"]   # Structured logging
  config.reflex_url = ENV["BRAINZLAB_REFLEX_URL"]   # Error tracking
  config.pulse_url  = ENV["BRAINZLAB_PULSE_URL"]    # APM & distributed tracing
  config.flux_url   = ENV["BRAINZLAB_FLUX_URL"]     # Feature flags

  # Alerting & Secrets
  config.signal_url = ENV["BRAINZLAB_SIGNAL_URL"]   # Alerting hub
  config.vault_url  = ENV["BRAINZLAB_VAULT_URL"]    # Secrets management
end
