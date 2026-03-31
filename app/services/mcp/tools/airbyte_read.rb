# frozen_string_literal: true

module Mcp
  module Tools
    class AirbyteRead < Base
      DESCRIPTION = "Read data from a specific stream of an Airbyte manifest connector"
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          connection_id: {
            type: "string",
            description: "The connection ID to use (must have stored credentials)"
          },
          stream: {
            type: "string",
            description: "The stream name to read (e.g., 'contacts', 'deals')"
          },
          limit: {
            type: "integer",
            description: "Maximum number of records to return (default: 100)"
          }
        },
        required: [ "connection_id", "stream" ]
      }.freeze

      def call(params)
        connection_id = params["connection_id"] || params[:connection_id]
        stream_name = params["stream"] || params[:stream]
        limit = (params["limit"] || params[:limit] || 100).to_i

        connection = project.connector_connections.connected.find_by(id: connection_id)
        return error("Connection not found or not active") unless connection

        connector = connection.connector
        return error("Not an Airbyte connector") unless connector.airbyte?
        return error("No manifest available") unless connector.manifest_yaml.present?

        credentials = connection.connector_credential&.decrypt_credentials || {}

        engine = Connectors::Manifest::Engine.new(connector.manifest_yaml, credentials)
        records = engine.execute(stream_name)
        records = records.first(limit) if records.length > limit

        connection.record_execution!
        log_access(action: "airbyte_read", details: {
          piece_name: connector.piece_name,
          stream: stream_name,
          records_count: records.length
        })

        success(stream: stream_name, records: records, count: records.length)
      rescue Connectors::ActionNotFoundError => e
        error(e.message)
      rescue StandardError => e
        error("Read failed: #{e.message}")
      end
    end
  end
end
