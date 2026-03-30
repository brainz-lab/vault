# frozen_string_literal: true

module Connectors
  module Manifest
    # Resolves Jinja-like template expressions used in Airbyte manifest YAMLs.
    #
    # Supports:
    #   {{ config['api_key'] }}
    #   {{ parameters['cursor'] }}
    #   {{ response['next_page'] }}
    #   {{ headers['x-next-cursor'] }}
    #   {{ next_page_token['offset'] }}
    #   {{ stream_interval.start_time }}
    #   {{ stream_slice.partition }}
    #
    class Interpolator
      TEMPLATE_PATTERN = /\{\{\s*(.+?)\s*\}\}/

      def initialize(config:, parameters: {}, response: nil, headers: nil, next_page_token: nil, stream_interval: nil, stream_slice: nil)
        @config = config || {}
        @parameters = parameters || {}
        @response = response
        @headers = headers || {}
        @next_page_token = next_page_token
        @stream_interval = stream_interval || {}
        @stream_slice = stream_slice || {}
      end

      def interpolate(value)
        case value
        when String
          interpolate_string(value)
        when Hash
          value.transform_values { |v| interpolate(v) }
        when Array
          value.map { |v| interpolate(v) }
        else
          value
        end
      end

      private

      def interpolate_string(str)
        str.gsub(TEMPLATE_PATTERN) do |_match|
          expression = Regexp.last_match(1).strip
          resolve_expression(expression).to_s
        end
      end

      def resolve_expression(expression)
        # Handle bracket notation: config['key'] or config["key"]
        if expression.match?(/\A(\w+)\[['"](.+?)['"]\]\z/)
          match = expression.match(/\A(\w+)\[['"](.+?)['"]\]\z/)
          resolve_lookup(match[1], match[2])

        # Handle dot notation: config.key or stream_interval.start_time
        elsif expression.match?(/\A(\w+)\.(\w+)\z/)
          match = expression.match(/\A(\w+)\.(\w+)\z/)
          resolve_lookup(match[1], match[2])

        # Handle nested bracket: response['data']['cursor']
        elsif expression.match?(/\A(\w+)(\[['"].+?['"]\])+\z/)
          resolve_nested(expression)

        # Simple variable reference
        else
          resolve_variable(expression)
        end
      end

      def resolve_lookup(namespace, key)
        context = context_for(namespace)
        return "" unless context.is_a?(Hash)

        context[key] || context[key.to_sym] || ""
      end

      def resolve_nested(expression)
        parts = expression.scan(/\A(\w+)|(?:\[['"](.+?)['"]\])/)
        return "" if parts.empty?

        namespace = parts.shift&.compact&.first
        current = context_for(namespace)

        parts.each do |part|
          key = part.compact.first
          break unless current.is_a?(Hash)
          current = current[key] || current[key.to_sym]
        end

        current || ""
      end

      def resolve_variable(name)
        context_for(name) || ""
      end

      def context_for(namespace)
        case namespace
        when "config" then @config
        when "parameters" then @parameters
        when "response" then @response
        when "headers" then @headers
        when "next_page_token" then @next_page_token
        when "stream_interval" then @stream_interval
        when "stream_slice" then @stream_slice
        else nil
        end
      end
    end
  end
end
