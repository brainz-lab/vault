# frozen_string_literal: true

module Connectors
  module Manifest
    # Extracts records from HTTP response bodies using dpath expressions.
    #
    # Maps to Airbyte's DpathExtractor: navigates nested JSON using a field_path array.
    #
    # Examples:
    #   field_path: ["data"]          → response["data"]
    #   field_path: ["results", "*"]  → response["results"] (array)
    #   field_path: []                → response itself (if array)
    #
    class RecordSelector
      def initialize(extractor_config, interpolator: nil)
        @field_path = extractor_config["field_path"] || extractor_config[:field_path] || []
        @interpolator = interpolator
      end

      def extract(response_body)
        return [] unless response_body

        data = dig_path(response_body, resolved_path)

        case data
        when Array then data
        when Hash then [ data ]
        else []
        end
      end

      private

      def resolved_path
        if @interpolator
          @field_path.map { |segment| @interpolator.interpolate(segment) }
        else
          @field_path
        end
      end

      def dig_path(data, path)
        return data if path.empty?

        current = data
        path.each do |segment|
          case segment
          when "*"
            # Wildcard: current should be an array, return it
            return current if current.is_a?(Array)
            return []
          else
            if current.is_a?(Hash)
              current = current[segment] || current[segment.to_sym]
            elsif current.is_a?(Array) && segment.match?(/\A\d+\z/)
              current = current[segment.to_i]
            else
              return []
            end
          end
        end
        current
      end
    end
  end
end
