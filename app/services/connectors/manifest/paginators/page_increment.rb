# frozen_string_literal: true

module Connectors
  module Manifest
    module Paginators
      # Maps to Airbyte's PageIncrement
      #
      # YAML:
      #   type: DefaultPaginator
      #   pagination_strategy:
      #     type: PageIncrement
      #     page_size: 100
      #     start_from_page: 1
      #   page_token_option:
      #     type: RequestOption
      #     field_name: "page"
      #     inject_into: request_parameter
      #
      class PageIncrement < Base
        def initialize(config, interpolator:)
          super
          @strategy = config["pagination_strategy"] || config[:pagination_strategy] || {}
          @page_token_option = config["page_token_option"] || config[:page_token_option] || {}
          @page_size_option = config["page_size_option"] || config[:page_size_option] || {}
          @page_size = (@strategy["page_size"] || @strategy[:page_size] || 100).to_i
          @current_page = (@strategy["start_from_page"] || @strategy[:start_from_page] || 0).to_i
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
          records = records.values.first if records.is_a?(Hash) && records.values.first.is_a?(Array)

          if records.is_a?(Array) && records.length < @page_size
            @has_more = false
          else
            @current_page += 1
          end
        end

        def next_page_token
          @has_more ? { "next_page_token" => @current_page.to_s } : nil
        end

        private

        def build_params
          params = {}

          if @page_size_option.present?
            size_field = @page_size_option["field_name"] || @page_size_option[:field_name] || "per_page"
            params[size_field] = @page_size
          end

          if @page_token_option.present?
            page_field = @page_token_option["field_name"] || @page_token_option[:field_name] || "page"
            params[page_field] = @current_page
          end

          params
        end
      end
    end
  end
end
