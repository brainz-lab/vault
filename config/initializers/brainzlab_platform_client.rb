# config/initializers/brainzlab_platform_client.rb
#
# Transaction reporting to BrainzLab Platform.
# PLATFORM_SERVICE_KEY is Platform's own SERVICE_KEY (used for Bearer auth to the batch endpoint).
# Falls back to SERVICE_KEY for backward compatibility.
#
platform_key = ENV["PLATFORM_SERVICE_KEY"] || ENV["SERVICE_KEY"]
return unless platform_key

BrainzLab::PlatformClient.configure do |config|
  config.service_name = "vault"
  config.service_key  = platform_key
  config.platform_url = ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://localhost:3000")
end
