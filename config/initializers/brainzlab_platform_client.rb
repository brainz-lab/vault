# config/initializers/brainzlab_platform_client.rb
#
# Transaction reporting to BrainzLab Platform.
# Requires SERVICE_KEY and BRAINZLAB_PLATFORM_URL env vars.
#
return unless ENV["SERVICE_KEY"]

BrainzLab::PlatformClient.configure do |config|
  config.service_name = "vault"
  config.service_key  = ENV["SERVICE_KEY"]
  config.platform_url = ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://localhost:3000")
end
