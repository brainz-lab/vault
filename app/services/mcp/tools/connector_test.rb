module Mcp
  module Tools
    class ConnectorTest < Base
      DESCRIPTION = "Test a connector connection to verify credentials and connectivity."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          connection_id: { type: "string", description: "The connection ID to test" },
          piece_name: { type: "string", description: "Or find connection by piece name" }
        },
        required: []
      }.freeze

      def call(params)
        connection = if params[:connection_id].present?
          project.connector_connections.find_by(id: params[:connection_id])
        elsif params[:piece_name].present?
          connector = Connector.find_by(piece_name: params[:piece_name])
          project.connector_connections.active.find_by(connector: connector) if connector
        end

        return error("Connection not found") unless connection

        connector = connection.connector
        credential = connection.connector_credential

        if credential.present? && connector.activepieces?
          credentials = credential.decrypt_credentials
          sidecar_url = ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
          sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]

          response = Faraday.new(url: sidecar_url) do |f|
            f.request :json
            f.response :json
            f.options.timeout = 30
          end.post("/validate") do |req|
            req.headers["Authorization"] = "Bearer #{sidecar_key}" if sidecar_key.present?
            req.body = { piece: connector.piece_name, auth: credentials }
          end

          if response.success? && response.body["valid"]
            connection.mark_connected!
            credential.mark_verified!
            success(valid: true, status: "connected")
          else
            msg = response.body["error"] || "Test failed"
            connection.mark_error!(msg)
            success(valid: false, error: msg)
          end
        else
          connection.mark_connected!
          credential&.mark_verified!
          success(valid: true, status: "connected")
        end
      rescue Faraday::Error => e
        error("Sidecar unavailable: #{e.message}")
      end
    end
  end
end
