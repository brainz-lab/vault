# frozen_string_literal: true

module Connectors
  module Manifest
    module Authenticators
      # Maps to Airbyte's BearerAuthenticator
      #
      # YAML:
      #   type: BearerAuthenticator
      #   api_token: "{{ config['api_key'] }}"
      #
      class Bearer < Base
        def apply(request)
          token = resolve(config["api_token"] || config[:api_token] || "{{ config['api_key'] }}")
          raise Connectors::AuthenticationError, "Bearer token is blank" if token.blank?

          request.headers["Authorization"] = "Bearer #{token}"
        end
      end
    end
  end
end
