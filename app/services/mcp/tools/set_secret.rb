module Mcp
  module Tools
    class SetSecret < Base
      DESCRIPTION = "Create or update a secret in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the secret"
          },
          value: {
            type: "string",
            description: "The secret value to store"
          },
          environment: {
            type: "string",
            description: "Optional environment slug (defaults to development)"
          },
          description: {
            type: "string",
            description: "Optional description of the secret"
          },
          note: {
            type: "string",
            description: "Optional note for this version"
          }
        },
        required: ["key", "value"]
      }.freeze

      def call(params)
        key = params[:key]
        value = params[:value]

        return error("key is required") unless key.present?
        return error("value is required") unless value.present?

        secret = project.secrets.find_or_initialize_by(key: key)
        was_new = secret.new_record?

        if params[:description].present?
          secret.description = params[:description]
        end

        ActiveRecord::Base.transaction do
          secret.save!
          secret.set_value(environment, value, user: nil, note: params[:note])
        end

        log_access(
          action: was_new ? "mcp_create_secret" : "mcp_update_secret",
          secret: secret,
          details: { environment: environment.slug }
        )

        success(
          key: secret.key,
          created: was_new,
          environment: environment.slug,
          version: secret.current_version_number
        )
      end
    end
  end
end
