class ConnectorCatalogSyncJob < ApplicationJob
  queue_as :default

  def perform
    stats = Connectors::CatalogSync.new.sync!
    Rails.logger.info "[ConnectorCatalogSyncJob] #{stats.inspect}"
  rescue Connectors::SidecarUnavailableError => e
    Rails.logger.warn "[ConnectorCatalogSyncJob] Sidecar unavailable: #{e.message}"
  end
end
