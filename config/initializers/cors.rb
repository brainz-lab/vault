# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed = ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").map(&:strip)

    if Rails.env.development? || Rails.env.test?
      allowed += %w[http://localhost:3000 http://localhost:4006 http://platform.localhost:2999]
    end

    origins(*allowed.reject(&:blank?))

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ]
  end
end
