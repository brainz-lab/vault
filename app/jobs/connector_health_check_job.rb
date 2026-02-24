class ConnectorHealthCheckJob < ApplicationJob
  queue_as :default

  def perform
    check_sidecar_health
    check_expired_credentials
  end

  private

  def check_sidecar_health
    sidecar_url = ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
    sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]

    response = Faraday.new(url: sidecar_url) do |f|
      f.response :json
      f.options.timeout = 10
    end.get("/health") do |req|
      req.headers["Authorization"] = "Bearer #{sidecar_key}" if sidecar_key.present?
    end

    if response.success?
      Rails.logger.info "[ConnectorHealthCheckJob] Sidecar healthy: #{response.body}"
    else
      Rails.logger.warn "[ConnectorHealthCheckJob] Sidecar unhealthy: HTTP #{response.status}"
    end
  rescue Faraday::Error => e
    Rails.logger.error "[ConnectorHealthCheckJob] Sidecar unreachable: #{e.message}"
  end

  def check_expired_credentials
    expired = ConnectorCredential.where(status: "active")
      .where("token_expires_at IS NOT NULL AND token_expires_at < ?", Time.current)

    expired.find_each do |credential|
      credential.update!(status: "expired")
      Rails.logger.info "[ConnectorHealthCheckJob] Credential expired: #{credential.id} (#{credential.name})"
    end

    Rails.logger.info "[ConnectorHealthCheckJob] Marked #{expired.size} credentials as expired" if expired.any?
  end
end
