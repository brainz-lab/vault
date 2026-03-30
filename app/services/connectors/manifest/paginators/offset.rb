# frozen_string_literal: true

module Connectors
  module Manifest
    module Paginators
      # Maps to Airbyte's OffsetIncrement
      #
      # YAML:
      #   type: DefaultPaginator
      #   pagination_strategy:
      #     type: OffsetIncrement
      #     page_size: 100
      #   page_size_option:
      #     type: RequestOption
      #     field_name: "limit"
      #     inject_into: request_parameter
      #   page_token_option:
      #     type: RequestOption
      #     field_name: "offset"
      #     inject_into: request_parameter
      #
      class Offset < Base
        def initialize(config, interpolator:)
          super
          @strategy = config["pagination_strategy"] || config[:pagination_strategy] || {}
          @page_token_option = config["page_token_option"] || config[:page_token_option] || {}
          @page_size_option = config["page_size_option"] || config[:page_size_option] || {}
          @page_size = (@strategy["page_size"] || @strategy[:page_size] || 100).to_i
          @current_offset = 0
          @has_more = true
        end

        def each_page
          loop do
            guard_infinite_loop!
            params = build_params
            yield params

            break unless @has_more
          end
        end

        def update_from_response(response_body, _headers = {})
          records = response_body
          if records.is_a?(Hash)
            # Check for explicit "no more pages" signals
            has_next = records.dig("_links", "next").present? ||
                       records.dig("next_page").present? ||
                       records.dig("has_more") == true ||
                       records.dig("hasMore") == true

            # Extract the records array
            records = records["results"] || records["items"] || records["data"] ||
                      records.values.find { |v| v.is_a?(Array) }

            # If response has pagination metadata and no next link, stop
            if response_body.is_a?(Hash) && response_body.key?("_links") && !has_next
              @has_more = false
              @current_offset += @page_size
              return
            end
          end

          if records.is_a?(Array) && records.length < @page_size
            @has_more = false
          end

          @current_offset += @page_size
        end

        def next_page_token
          @has_more ? { "next_page_token" => @current_offset.to_s } : nil
        end

        private

        def build_params
          params = {}

          if @page_size_option.present?
            size_field = @page_size_option["field_name"] || @page_size_option[:field_name] || "limit"
            params[size_field] = @page_size
          end

          if @page_token_option.present?
            offset_field = @page_token_option["field_name"] || @page_token_option[:field_name] || "offset"
            params[offset_field] = @current_offset
          end

          params
        end
      end
    end
  end
end
