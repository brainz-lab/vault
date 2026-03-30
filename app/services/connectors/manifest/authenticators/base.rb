# frozen_string_literal: true

module Connectors
  module Manifest
    module Authenticators
      class Base
        def initialize(config, credentials, interpolator:)
          @config = config || {}
          @credentials = credentials || {}
          @interpolator = interpolator
        end

        # Apply authentication to a Faraday request
        def apply(request)
          raise NotImplementedError, "#{self.class}#apply must be implemented"
        end

        private

        attr_reader :config, :credentials, :interpolator

        def resolve(value)
          interpolator.interpolate(value)
        end
      end
    end
  end
end
