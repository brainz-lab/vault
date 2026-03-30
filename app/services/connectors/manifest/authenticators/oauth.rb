# frozen_string_literal: true

module Connectors
  module Manifest
    module Authenticators
      # Maps to Airbyte's OAuthAuthenticator
      #
      # For manifest-based connectors, OAuth tokens are already managed by Vault's
      # credential system (ConnectorCredential with oauth? type). The access_token
      # arrives pre-refreshed in the credentials hash.
      #
      # YAML:
      #   type: OAuthAuthenticator
      #   token_refresh_endpoint: "https://api.example.com/oauth/token"
      #   client_id: "{{ config['client_id'] }}"
      #   client_secret: "{{ config['client_secret'] }}"
      #   refresh_token: "{{ config['refresh_token'] }}"
      #   access_token: "{{ config['access_token'] }}"
      #
      class Oauth < Base
        def apply(request)
          token = credentials[:access_token] || credentials["access_token"]
          raise Connectors::AuthenticationError, "OAuth access_token not available" if token.blank?

          request.headers["Authorization"] = "Bearer #{token}"
        end
      end
    end
  end
end
