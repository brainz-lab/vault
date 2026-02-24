module Connectors
  class CatalogSync
    def initialize(sidecar_url: nil)
      @sidecar_url = sidecar_url || ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
      @sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]
    end

    def sync!
      pieces = fetch_catalog
      stats = { created: 0, updated: 0, errors: 0 }

      pieces.each do |piece|
        upsert_connector(piece, stats)
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error "[CatalogSync] Error syncing #{piece['name']}: #{e.message}"
      end

      Rails.logger.info "[CatalogSync] Sync complete: #{stats.inspect}"
      stats
    end

    private

    def fetch_catalog
      response = Faraday.new(url: @sidecar_url) do |f|
        f.response :json
        f.options.timeout = 60
      end.get("/catalog") do |req|
        req.headers["Authorization"] = "Bearer #{@sidecar_key}" if @sidecar_key.present?
      end

      raise SidecarUnavailableError, "Sidecar returned HTTP #{response.status}" unless response.success?

      response.body
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise SidecarUnavailableError, "Cannot reach sidecar: #{e.message}"
    end

    def upsert_connector(piece, stats)
      connector = Connector.find_or_initialize_by(piece_name: piece["name"])
      was_new = connector.new_record?

      connector.assign_attributes(
        display_name: piece["displayName"] || piece["name"].titleize,
        description: piece["description"],
        logo_url: piece["logoUrl"],
        category: normalize_category(piece["category"]),
        connector_type: "activepieces",
        auth_type: piece.dig("auth", "type"),
        auth_schema: piece["auth"] || {},
        version: piece["version"],
        package_name: piece["packageName"],
        actions: normalize_actions(piece["actions"]),
        triggers: normalize_triggers(piece["triggers"]),
        installed: true,
        enabled: true
      )

      connector.save!
      was_new ? stats[:created] += 1 : stats[:updated] += 1
    end

    def normalize_category(category)
      return "other" unless category.present?
      normalized = category.to_s.downcase.gsub(/[^a-z_]/, "_")
      Connector::CATEGORIES.include?(normalized) ? normalized : "other"
    end

    def normalize_actions(actions)
      return [] unless actions.is_a?(Hash) || actions.is_a?(Array)

      items = actions.is_a?(Hash) ? actions.values : actions
      items.map do |action|
        {
          "name" => action["name"],
          "displayName" => action["displayName"],
          "description" => action["description"],
          "props" => action["props"]
        }.compact
      end
    end

    def normalize_triggers(triggers)
      return [] unless triggers.is_a?(Hash) || triggers.is_a?(Array)

      items = triggers.is_a?(Hash) ? triggers.values : triggers
      items.map do |trigger|
        {
          "name" => trigger["name"],
          "displayName" => trigger["displayName"],
          "description" => trigger["description"],
          "props" => trigger["props"]
        }.compact
      end
    end
  end
end
