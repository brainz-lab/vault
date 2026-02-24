class ConnectorInstallPieceJob < ApplicationJob
  queue_as :default

  def perform(package_name)
    sidecar_url = ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
    sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]

    response = Faraday.new(url: sidecar_url) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 120
    end.post("/install") do |req|
      req.headers["Authorization"] = "Bearer #{sidecar_key}" if sidecar_key.present?
      req.body = { package: package_name }
    end

    if response.success? && response.body["success"]
      Rails.logger.info "[ConnectorInstallPieceJob] Installed #{package_name} v#{response.body['version']}"
      # Trigger catalog sync to pick up the new piece
      ConnectorCatalogSyncJob.perform_later
    else
      Rails.logger.error "[ConnectorInstallPieceJob] Failed to install #{package_name}: #{response.body['error']}"
    end
  rescue Faraday::Error => e
    Rails.logger.error "[ConnectorInstallPieceJob] Sidecar error installing #{package_name}: #{e.message}"
  end
end
