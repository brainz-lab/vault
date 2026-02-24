module Mcp
  module Tools
    class ConnectorSetCredential < Base
      DESCRIPTION = "Store or update encrypted credentials for a connector."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          piece_name: { type: "string", description: "The connector piece name" },
          name: { type: "string", description: "A name for this credential set" },
          credentials: { type: "object", description: "The credential values to encrypt and store" }
        },
        required: [ "piece_name", "credentials" ]
      }.freeze

      def call(params)
        return error("piece_name is required") unless params[:piece_name].present?
        return error("credentials is required") unless params[:credentials].present?

        connector = Connector.enabled.find_by(piece_name: params[:piece_name])
        return error("Connector not found: #{params[:piece_name]}") unless connector

        name = params[:name] || params[:piece_name]

        existing = project.connector_credentials.find_by(connector: connector, name: name)

        if existing
          existing.update_credentials(params[:credentials])
          log_access(action: "mcp_update_connector_credential", details: { piece_name: params[:piece_name], name: name })
          success(existing.to_summary.merge(updated: true))
        else
          credential = ConnectorCredential.create_encrypted(
            project: project,
            connector: connector,
            name: name,
            auth_type: connector.auth_type || "SECRET_TEXT",
            credentials: params[:credentials]
          )
          log_access(action: "mcp_create_connector_credential", details: { piece_name: params[:piece_name], name: name })
          success(credential.to_summary.merge(created: true))
        end
      rescue ActiveRecord::RecordInvalid => e
        error("Failed to save credential: #{e.message}")
      end
    end
  end
end
