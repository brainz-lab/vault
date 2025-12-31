module Mcp
  module Tools
    class GetSecret < Base
      DESCRIPTION = "Retrieve the value of a secret from the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the secret to retrieve"
          },
          environment: {
            type: "string",
            description: "Optional environment slug (defaults to development)"
          }
        },
        required: [ "key" ]
      }.freeze

      def call(params)
        key = params[:key]
        return error("key is required") unless key.present?

        secret = project.secrets.active.find_by(key: key)
        return error("Secret not found: #{key}") unless secret

        value = environment.resolve_value(secret)

        log_access(
          action: "mcp_get_secret",
          secret: secret,
          details: { environment: environment.slug }
        )

        success(
          key: secret.key,
          value: value,
          environment: environment.slug,
          version: secret.current_version_number
        )
      end
    end
  end
end
