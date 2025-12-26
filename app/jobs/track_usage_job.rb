class TrackUsageJob < ApplicationJob
  queue_as :low

  def perform(project_id:, product:, metric:, count:)
    return unless platform_configured?

    response = platform_connection.post("/api/v1/usage/track") do |req|
      req.headers["X-Service-Key"] = service_key
      req.body = {
        project_id: project_id,
        product: product,
        metric: metric,
        count: count,
        timestamp: Time.current.iso8601
      }.to_json
    end

    unless response.success?
      Rails.logger.warn "[TrackUsageJob] Failed to track usage: #{response.status}"
    end
  rescue Faraday::Error => e
    Rails.logger.error "[TrackUsageJob] Error tracking usage: #{e.message}"
  end

  private

  def platform_connection
    @platform_connection ||= Faraday.new(platform_url) do |f|
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
end
