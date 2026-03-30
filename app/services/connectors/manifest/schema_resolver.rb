# frozen_string_literal: true

module Connectors
  module Manifest
    # Resolves JSON schemas for streams from manifest configuration.
    #
    # Maps to Airbyte's schema_loader types:
    # - InlineSchemaLoader: schema defined directly in YAML
    # - JsonFileSchemaLoader: references a JSON schema file (we inline it during seeding)
    #
    class SchemaResolver
      def initialize(schema_config)
        @config = schema_config || {}
      end

      def resolve
        type = @config["type"] || @config[:type]

        case type
        when "InlineSchemaLoader"
          @config["schema"] || @config[:schema] || {}
        else
          # For JsonFileSchemaLoader or unknown types, return inline schema if present
          @config["schema"] || @config[:schema] || {}
        end
      end
    end
  end
end
