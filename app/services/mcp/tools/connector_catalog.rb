module Mcp
  module Tools
    class ConnectorCatalog < Base
      DESCRIPTION = "Browse and search the connector catalog. Returns available connectors with filtering by type, category, or search query."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          type: { type: "string", enum: %w[activepieces native airbyte], description: "Filter by connector type" },
          category: { type: "string", description: "Filter by category (e.g. communication, crm, data)" },
          q: { type: "string", description: "Search query to match against name or description" },
          installed: { type: "boolean", description: "Only show installed connectors" }
        },
        required: []
      }.freeze

      def call(params)
        connectors = Connector.enabled

        connectors = connectors.by_type(params[:type]) if params[:type].present?
        connectors = connectors.by_category(params[:category]) if params[:category].present?
        connectors = connectors.search(params[:q]) if params[:q].present?
        connectors = connectors.installed if params[:installed]

        connectors = connectors.order(:display_name)

        log_access(action: "mcp_connector_catalog", details: params.slice(:type, :category, :q))

        success(
          connectors: connectors.map(&:to_catalog_entry),
          total: connectors.size,
          categories: Connector.enabled.distinct.pluck(:category).sort
        )
      end
    end
  end
end
