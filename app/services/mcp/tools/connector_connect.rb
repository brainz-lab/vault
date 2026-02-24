module Mcp
  module Tools
    class ConnectorConnect < Base
      DESCRIPTION = "Connect a connector to the current project with optional credentials."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          piece_name: { type: "string", description: "The connector piece name (e.g. 'slack', 'webhook')" },
          name: { type: "string", description: "Display name for this connection" },
          credentials: { type: "object", description: "Auth credentials (will be encrypted)" },
          credential_name: { type: "string", description: "Name for the stored credential (default: piece_name)" },
          config: { type: "object", description: "Additional configuration" }
        },
        required: [ "piece_name" ]
      }.freeze

      def call(params)
        piece_name = params[:piece_name]
        return error("piece_name is required") unless piece_name.present?

        connector = Connector.enabled.find_by(piece_name: piece_name)
        return error("Connector not found: #{piece_name}") unless connector

        credential = nil
        if params[:credentials].present? && connector.requires_auth?
          credential = ConnectorCredential.create_encrypted(
            project: project,
            connector: connector,
            name: params[:credential_name] || piece_name,
            auth_type: connector.auth_type,
            credentials: params[:credentials]
          )
        end

        connection = project.connector_connections.create!(
          connector: connector,
          connector_credential: credential,
          name: params[:name] || connector.display_name,
          config: params[:config] || {},
          status: "connected",
          enabled: true
        )

        log_access(action: "mcp_connector_connect", details: { piece_name: piece_name })

        success(connection.to_summary)
      rescue ActiveRecord::RecordInvalid => e
        error("Failed to connect: #{e.message}")
      end
    end
  end
end
