# frozen_string_literal: true

module Connectors
  module Manifest
    module Authenticators
      class NoAuth < Base
        def apply(request)
          # No authentication needed
        end
      end
    end
  end
end
