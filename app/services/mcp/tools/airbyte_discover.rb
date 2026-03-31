# frozen_string_literal: true

module Mcp
  module Tools
    class AirbyteDiscover < Base
      DESCRIPTION = "Discover available streams (tables/resources) for an Airbyte manifest connector"
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          piece_name: {
            type: "string",
            description: "The piece_name of the Airbyte connector (e.g., 'airbyte-source-hubspot')"
          },
          connection_id: {
            type: "string",
            description: "Optional connection ID. If provided, uses stored credentials."
          }
        },
        required: [ "piece_name" ]
      }.freeze

      def call(params)
        connector = Connector.find_by(piece_name: params["piece_name"] || params[:piece_name])
        return error("Connector not found") unless connector
        return error("Not an Airbyte connector") unless connector.airbyte?
        return error("No manifest available for this connector") unless connector.manifest_yaml.present?

        credentials = {}
        if params["connection_id"] || params[:connection_id]
          connection = project.connector_connections.find_by(id: params["connection_id"] || params[:connection_id])
          if connection&.connector_credential
            credentials = connection.connector_credential.decrypt_credentials
          end
        end

        engine = Connectors::Manifest::Engine.new(connector.manifest_yaml, credentials)
        streams = engine.discover_streams

        log_access(action: "airbyte_discover", details: { piece_name: connector.piece_name, streams: streams.length })
        success(streams: streams, connector: connector.piece_name)
      rescue StandardError => e
        error("Discovery failed: #{e.message}")
      end
    end
  end
end
