module Mcp
  module Tools
    class GetHistory < Base
      DESCRIPTION = "Get version history for a secret."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the secret"
          },
          limit: {
            type: "integer",
            description: "Maximum number of versions to return (default: 10)"
          }
        },
        required: [ "key" ]
      }.freeze

      def call(params)
        key = params[:key]
        limit = (params[:limit] || 10).to_i.clamp(1, 100)

        return error("key is required") unless key.present?

        secret = project.secrets.find_by(key: key)
        return error("Secret not found: #{key}") unless secret

        versions = secret.versions
                         .where(secret_environment: environment)
                         .order(version: :desc)
                         .limit(limit)

        log_access(
          action: "mcp_get_history",
          secret: secret,
          details: { environment: environment.slug }
        )

        success(
          key: secret.key,
          environment: environment.slug,
          versions: versions.map do |v|
            {
              version: v.version,
              created_at: v.created_at.iso8601,
              created_by: v.created_by,
              note: v.change_note
            }
          end
        )
      end
    end
  end
end
