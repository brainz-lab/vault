# frozen_string_literal: true

module Connectors
  module Manifest
    module Paginators
      # Maps to Airbyte's CursorPagination
      #
      # YAML:
      #   type: DefaultPaginator
      #   pagination_strategy:
      #     type: CursorPagination
      #     cursor_value: "{{ response['next_cursor'] }}"
      #     stop_condition: "{{ not response['has_more'] }}"
      #     page_size: 100
      #   page_token_option:
      #     type: RequestOption
      #     field_name: "cursor"
      #     inject_into: request_parameter
      #   page_size_option:
      #     type: RequestOption
      #     field_name: "limit"
      #     inject_into: request_parameter
      #
      class Cursor < Base
        def initialize(config, interpolator:)
          super
          @strategy = config["pagination_strategy"] || config[:pagination_strategy] || {}
          @page_token_option = config["page_token_option"] || config[:page_token_option] || {}
          @page_size_option = config["page_size_option"] || config[:page_size_option] || {}
          @current_cursor = nil
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

        def update_from_response(response_body, response_headers = {})
          cursor_template = @strategy["cursor_value"] || @strategy[:cursor_value]
          return stop! unless cursor_template

          response_interpolator = Interpolator.new(
            config: interpolator.instance_variable_get(:@config),
            parameters: interpolator.instance_variable_get(:@parameters),
            response: response_body,
            headers: response_headers,
            next_page_token: { "next_page_token" => @current_cursor }
          )

          @current_cursor = response_interpolator.interpolate(cursor_template)

          stop_template = @strategy["stop_condition"] || @strategy[:stop_condition]
          if stop_template
            stop_value = response_interpolator.interpolate(stop_template)
            stop! if truthy_stop?(stop_value)
          end

          stop! if @current_cursor.blank?
        end

        def next_page_token
          @current_cursor ? { "next_page_token" => @current_cursor } : nil
        end

        private

        def build_params
          params = {}

          if @page_size_option.present?
            size_field = @page_size_option["field_name"] || @page_size_option[:field_name]
            page_size = @strategy["page_size"] || @strategy[:page_size]
            params[size_field] = page_size if size_field && page_size
          end

          if @current_cursor.present? && @page_token_option.present?
            token_field = @page_token_option["field_name"] || @page_token_option[:field_name]
            params[token_field] = @current_cursor if token_field
          end

          params
        end

        def stop!
          @has_more = false
        end

        def truthy_stop?(value)
          case value.to_s.downcase.strip
          when "true", "1", "yes" then true
          else false
          end
        end
      end
    end
  end
end
