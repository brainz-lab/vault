# frozen_string_literal: true

module Mcp
  module Tools
    class AirbyteCheck < Base
      DESCRIPTION = "Test connection credentials for an Airbyte manifest connector"
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          connection_id: {
            type: "string",
            description: "The connection ID to test"
          }
        },
        required: [ "connection_id" ]
      }.freeze

      def call(params)
        connection_id = params["connection_id"] || params[:connection_id]

        connection = project.connector_connections.find_by(id: connection_id)
        return error("Connection not found") unless connection

        connector = connection.connector
        return error("Not an Airbyte connector") unless connector.airbyte?
        return error("No manifest available") unless connector.manifest_yaml.present?

        credentials = connection.connector_credential&.decrypt_credentials || {}
        engine = Connectors::Manifest::Engine.new(connector.manifest_yaml, credentials)
        connected = engine.check_connection

        if connected
          connection.mark_connected! if connection.respond_to?(:mark_connected!)
          log_access(action: "airbyte_check", details: { piece_name: connector.piece_name, result: "success" })
          success(status: "connected", connector: connector.piece_name)
        else
          log_access(action: "airbyte_check", details: { piece_name: connector.piece_name, result: "failed" })
          error("Connection check failed — could not read from check stream")
        end
      rescue StandardError => e
        error("Check failed: #{e.message}")
      end
    end
  end
end
