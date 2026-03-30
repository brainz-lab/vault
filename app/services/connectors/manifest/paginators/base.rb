# frozen_string_literal: true

module Connectors
  module Manifest
    module Paginators
      class Base
        MAX_PAGES = 1000

        def initialize(config, interpolator:)
          @config = config || {}
          @interpolator = interpolator
          @page_count = 0
        end

        # Yields page parameters for each page.
        # Implementations must call update_state after each response.
        def each_page
          raise NotImplementedError, "#{self.class}#each_page must be implemented"
        end

        # Returns the next_page_token hash for interpolation, or nil if done.
        def next_page_token
          nil
        end

        private

        attr_reader :config, :interpolator

        def guard_infinite_loop!
          @page_count += 1
          raise Connectors::Error, "Pagination exceeded #{MAX_PAGES} pages" if @page_count > MAX_PAGES
        end
      end
    end
  end
end
