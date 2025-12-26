class PlatformClient
  class << self
    def validate_key(raw_key)
      return invalid_result("Missing API key") unless raw_key.present?

      # In development, skip Platform validation if not configured
      if Rails.env.development? && !platform_configured?
        return development_fallback_result
      end

      response = connection.post("/api/v1/keys/validate") do |req|
        req.headers["X-Service-Key"] = service_key
        req.body = { key: raw_key }.to_json
      end

      if response.success?
        data = JSON.parse(response.body, symbolize_names: true)
        {
          valid: data[:valid],
          project_id: data[:project_id],
          organization_id: data[:organization_id],
          features: data[:features] || {},
          limits: data[:limits] || {}
        }
      else
        invalid_result("Invalid API key")
      end
    rescue Faraday::Error => e
      Rails.logger.error "PlatformClient error: #{e.message}"
      if Rails.env.development?
        development_fallback_result
      else
        invalid_result("Platform service unavailable")
      end
    end

    def track_usage(project_id:, product:, metric:, count:)
      return unless platform_configured?

      TrackUsageJob.perform_later(
        project_id: project_id,
        product: product,
        metric: metric,
        count: count
      )
    end

    private

    def connection
      @connection ||= Faraday.new(platform_url) do |f|
        f.headers["Content-Type"] = "application/json"
        f.adapter Faraday.default_adapter
      end
    end

    def platform_url
      ENV["BRAINZLAB_PLATFORM_URL"] || "http://localhost:2999"
    end

    def service_key
      ENV["SERVICE_KEY"] || "dev_service_key"
    end

    def platform_configured?
      ENV["BRAINZLAB_PLATFORM_URL"].present?
    end

    def invalid_result(error)
      { valid: false, error: error }
    end

    def development_fallback_result
      {
        valid: true,
        project_id: SecureRandom.uuid,
        organization_id: SecureRandom.uuid,
        features: { vault: true },
        limits: { secrets: -1 }
      }
    end
  end
end
