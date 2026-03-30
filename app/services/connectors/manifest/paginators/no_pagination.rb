# frozen_string_literal: true

module Connectors
  module Manifest
    module Paginators
      # No pagination — single request, single page
      class NoPagination < Base
        def each_page
          yield({})
        end
      end
    end
  end
end
