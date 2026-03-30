# frozen_string_literal: true

class ManifestUpdateJob < ApplicationJob
  queue_as :maintenance

  def perform
    seeder = Connectors::AirbyteSeeder.new
    registry = seeder.send(:fetch_registry)
    sources = registry["sources"] || []

    stats = { checked: 0, updated: 0, breaking: 0, errors: 0 }

    Connector.manifest_ready.find_each do |connector|
      source = find_in_registry(sources, connector)
      next unless source

      stats[:checked] += 1
      latest_version = source["dockerImageTag"]
      next if connector.version == latest_version

      new_manifest = seeder.send(:fetch_manifest_yaml, source)
      next unless new_manifest

      # Validate parseable
      YAML.safe_load(new_manifest, permitted_classes: [Date, Time])

      changes = detect_changes(connector.manifest_yaml, new_manifest)

      if changes[:breaking]
        ConnectorUpdateLog.create!(
          connector: connector,
          old_version: connector.version,
          new_version: latest_version,
          change_type: "breaking",
          change_summary: changes[:summary],
          status: "pending_review"
        )
        stats[:breaking] += 1
      else
        connector.update!(
          manifest_yaml: new_manifest,
          version: latest_version,
          manifest_version: latest_version,
          manifest_fetched_at: Time.current
        )
        ConnectorUpdateLog.create!(
          connector: connector,
          old_version: connector.version,
          new_version: latest_version,
          change_type: "minor",
          change_summary: changes[:summary],
          status: "auto_applied"
        )
        stats[:updated] += 1
      end
    rescue StandardError => e
      stats[:errors] += 1
      Rails.logger.error "[ManifestUpdate] Failed for #{connector.piece_name}: #{e.message}"
    end

    Rails.logger.info "[ManifestUpdate] Complete: #{stats.inspect}"
    stats
  end

  private

  def find_in_registry(sources, connector)
    # Match by docker_repository stored in metadata
    docker_repo = connector.metadata&.dig("docker_repository") || connector.package_name
    sources.find { |s| s["dockerRepository"] == docker_repo }
  end

  def detect_changes(old_yaml, new_yaml)
    old_manifest = YAML.safe_load(old_yaml, permitted_classes: [Date, Time])
    new_manifest = YAML.safe_load(new_yaml, permitted_classes: [Date, Time])

    old_streams = (old_manifest["streams"] || []).filter_map { |s| s["name"] }
    new_streams = (new_manifest["streams"] || []).filter_map { |s| s["name"] }

    removed = old_streams - new_streams
    added = new_streams - old_streams

    {
      breaking: removed.any?,
      summary: { removed_streams: removed, added_streams: added }.compact_blank
    }
  end
end
