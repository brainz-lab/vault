# frozen_string_literal: true

module Connectors
  module Manifest
    module Authenticators
      # Maps to Airbyte's BasicHttpAuthenticator
      #
      # YAML:
      #   type: BasicHttpAuthenticator
      #   username: "{{ config['username'] }}"
      #   password: "{{ config['password'] }}"
      #
      class BasicHttp < Base
        def apply(request)
          username = resolve(config["username"] || config[:username] || "{{ config['username'] }}")
          password = resolve(config["password"] || config[:password] || "{{ config['password'] }}")

          encoded = Base64.strict_encode64("#{username}:#{password}")
          request.headers["Authorization"] = "Basic #{encoded}"
        end
      end
    end
  end
end
