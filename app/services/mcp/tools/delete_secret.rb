module Mcp
  module Tools
    class DeleteSecret < Base
      DESCRIPTION = "Archive (soft-delete) a secret from the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the secret to delete"
          }
        },
        required: ["key"]
      }.freeze

      def call(params)
        key = params[:key]
        return error("key is required") unless key.present?

        secret = project.secrets.active.find_by(key: key)
        return error("Secret not found: #{key}") unless secret

        secret.archive!

        log_access(action: "mcp_delete_secret", secret: secret)

        success(
          key: key,
          archived: true
        )
      end
    end
  end
end
