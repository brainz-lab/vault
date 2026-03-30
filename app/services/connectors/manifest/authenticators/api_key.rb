# frozen_string_literal: true

module Connectors
  module Manifest
    module Authenticators
      # Maps to Airbyte's ApiKeyAuthenticator
      #
      # YAML:
      #   type: ApiKeyAuthenticator
      #   api_token: "{{ config['api_key'] }}"
      #   inject_into:
      #     type: RequestOption
      #     field_name: "X-Api-Key"
      #     inject_into: header   # or request_parameter
      #
      class ApiKey < Base
        def apply(request)
          token = resolve(config["api_token"] || config[:api_token] || "{{ config['api_key'] }}")
          raise Connectors::AuthenticationError, "API key is blank" if token.blank?

          inject = config["inject_into"] || config[:inject_into] || {}
          field_name = inject["field_name"] || inject[:field_name] || "X-Api-Key"
          target = inject["inject_into"] || inject[:inject_into] || "header"

          case target.to_s
          when "header"
            request.headers[field_name] = token
          when "request_parameter"
            request.params[field_name] = token
          else
            request.headers[field_name] = token
          end
        end
      end
    end
  end
end
