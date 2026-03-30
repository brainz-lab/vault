# frozen_string_literal: true

module Connectors
  module Manifest
    # Core manifest interpreter: parses Airbyte YAML manifests and executes
    # HTTP-based connector operations natively in Ruby.
    #
    # Usage:
    #   engine = Connectors::Manifest::Engine.new(yaml_string, credentials)
    #   engine.discover_streams     # → [{ name: "contacts", schema: {...} }, ...]
    #   engine.check_connection     # → true/false
    #   engine.execute("contacts")  # → [{ id: 1, name: "Alice" }, ...]
    #
    class Engine
      def initialize(manifest_yaml, credentials)
        @manifest = YAML.safe_load(manifest_yaml, permitted_classes: [Date, Time])
        @credentials = (credentials || {}).deep_stringify_keys
        @definitions = @manifest["definitions"] || {}
        @streams_config = @manifest["streams"] || []
      end

      MAX_RECORDS = 10_000

      # Execute a named stream and return extracted records.
      def execute(stream_name, limit: nil, **params)
        stream = find_stream!(stream_name)
        retriever = build_retriever(stream, params)
        max = limit || MAX_RECORDS

        all_records = []
        catch(:limit_reached) do
          retriever.each_page_of_records do |records|
            all_records.concat(records)
            throw(:limit_reached) if all_records.length >= max
          end
        end
        all_records.first(max)
      end

      # Validate credentials by reading from the check stream (single page, fast).
      def check_connection
        check_config = @manifest["check"] || {}
        stream_names = check_config["stream_names"] || []
        return false if stream_names.empty?

        execute(stream_names.first, limit: 1)
        true
      rescue StandardError
        false
      end

      # List available streams with their schemas.
      def discover_streams
        @streams_config.map do |stream_config|
          stream = resolve_stream(stream_config)
          schema_loader = stream["schema_loader"] || stream["schema"] || {}
          schema = SchemaResolver.new(schema_loader).resolve

          {
            name: stream["name"],
            primary_key: stream["primary_key"],
            schema: schema
          }
        end
      end

      # List stream names.
      def stream_names
        @streams_config.map { |s| resolve_stream(s)["name"] }
      end

      private

      def find_stream!(name)
        stream_config = @streams_config.find do |s|
          resolved = resolve_stream(s)
          resolved["name"] == name
        end
        raise Connectors::ActionNotFoundError, "Stream '#{name}' not found in manifest" unless stream_config

        resolve_stream(stream_config)
      end

      # Resolve $ref and type-based definitions
      def resolve_stream(stream_config)
        resolved = deep_resolve(stream_config)
        resolved.is_a?(Hash) ? resolved : {}
      end

      def deep_resolve(obj)
        case obj
        when Hash
          if obj["$ref"]
            ref_path = obj["$ref"].to_s.sub("#/definitions/", "")
            resolved_ref = resolve_ref_path(ref_path)
            if resolved_ref
              # Merge: $ref provides base, local keys override/extend
              local_keys = obj.except("$ref")
              if local_keys.any?
                merged = deep_resolve(resolved_ref).merge(deep_resolve(local_keys))
                return merged
              else
                return deep_resolve(resolved_ref)
              end
            end
          end
          obj.transform_values { |v| deep_resolve(v) }
        when Array
          obj.map { |v| deep_resolve(v) }
        else
          obj
        end
      end

      # Resolve a $ref path like "streams/audit" by walking nested definitions
      def resolve_ref_path(path)
        # Try direct lookup first
        return @definitions[path] if @definitions.key?(path)

        # Walk nested path: "streams/audit" → definitions["streams"]["audit"]
        parts = path.split("/")
        current = @definitions
        parts.each do |part|
          return nil unless current.is_a?(Hash)
          current = current[part]
        end
        current
      end

      # Build the retriever pipeline for a stream
      def build_retriever(stream, params)
        Retriever.new(
          stream: stream,
          credentials: @credentials,
          definitions: @definitions,
          params: params
        )
      end

      # Internal class that orchestrates fetching + pagination + extraction for a stream
      class Retriever
        def initialize(stream:, credentials:, definitions:, params:)
          @stream = stream
          @credentials = credentials
          @definitions = definitions
          @params = params

          @interpolator = build_interpolator
          @authenticator = build_authenticator
          @error_handler = build_error_handler
          @paginator = build_paginator
          @selector = build_record_selector
          @requester = build_requester
          @slicer = build_slicer
        end

        def each_page_of_records(&block)
          @slicer.each_slice do |stream_slice|
            @interpolator = build_interpolator(stream_slice: stream_slice)
            fetch_all_pages(stream_slice, &block)
          end
        end

        private

        def fetch_all_pages(stream_slice)
          @paginator = build_paginator # reset for each slice

          @paginator.each_page do |page_params|
            merged_params = @params.merge(page_params)
            response_body = @requester.fetch(merged_params)

            records = @selector.extract(response_body)
            yield records if records.any?

            # Update paginator state from response
            if @paginator.respond_to?(:update_from_response)
              @paginator.update_from_response(response_body)
            end
          end
        end

        def build_interpolator(stream_slice: {})
          Interpolator.new(
            config: @credentials,
            parameters: @params.stringify_keys,
            stream_slice: stream_slice
          )
        end

        def build_authenticator
          requester_config = retriever_config["requester"] || @stream["requester"] || {}
          auth_config = requester_config["authenticator"] || {}
          auth_type = auth_config["type"] || auth_config[:type]

          klass = case auth_type
                  when "BearerAuthenticator" then Authenticators::Bearer
                  when "ApiKeyAuthenticator" then Authenticators::ApiKey
                  when "BasicHttpAuthenticator" then Authenticators::BasicHttp
                  when "OAuthAuthenticator" then Authenticators::Oauth
                  when "NoAuth", nil then Authenticators::NoAuth
                  else Authenticators::NoAuth
                  end

          klass.new(auth_config, @credentials, interpolator: @interpolator)
        end

        def build_error_handler
          requester_config = retriever_config["requester"] || @stream["requester"] || {}
          handler_config = requester_config["error_handler"] || {}
          ErrorHandler.new(handler_config)
        end

        def build_paginator
          paginator_config = retriever_config["paginator"] || @stream["paginator"] || {}
          strategy = paginator_config["pagination_strategy"] || paginator_config[:pagination_strategy] || {}
          strategy_type = strategy["type"] || strategy[:type]

          klass = case strategy_type
                  when "CursorPagination" then Paginators::Cursor
                  when "OffsetIncrement" then Paginators::Offset
                  when "PageIncrement" then Paginators::PageIncrement
                  else Paginators::NoPagination
                  end

          klass.new(paginator_config, interpolator: @interpolator)
        end

        def build_record_selector
          selector_config = retriever_config["record_selector"] || @stream["record_selector"] || {}
          extractor_config = selector_config["extractor"] || selector_config
          RecordSelector.new(extractor_config, interpolator: @interpolator)
        end

        def build_requester
          requester_config = retriever_config["requester"] || @stream["requester"] || {}
          HttpRequester.new(
            requester_config,
            interpolator: @interpolator,
            authenticator: @authenticator,
            error_handler: @error_handler
          )
        end

        def build_slicer
          slicer_config = retriever_config["partition_router"] || @stream["incremental_sync"] || {}
          StreamSlicer.new(slicer_config, interpolator: @interpolator)
        end

        def retriever_config
          @stream["retriever"] || {}
        end
      end
    end
  end
end
