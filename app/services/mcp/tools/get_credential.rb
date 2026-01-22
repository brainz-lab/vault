module Mcp
  module Tools
    class GetCredential < Base
      DESCRIPTION = "Retrieve a credential (username/password) with optional OTP code for automated login."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the credential secret"
          },
          environment: {
            type: "string",
            description: "Optional environment slug (defaults to development)"
          },
          include_otp: {
            type: "boolean",
            description: "Include OTP code if available (default: true)"
          }
        },
        required: [ "key" ]
      }.freeze

      def call(params)
        key = params[:key]
        return error("key is required") unless key.present?

        include_otp = params.fetch(:include_otp, true)

        secret = project.secrets.active.find_by(key: key)
        return error("Secret not found: #{key}") unless secret
        return error("Secret is not a credential type") unless secret.otp_enabled? || secret.credential?

        credential = secret.get_credential(environment, include_otp: include_otp)
        return error("No credential found for environment: #{environment.slug}") unless credential

        log_access(
          action: "mcp_get_credential",
          secret: secret,
          details: {
            environment: environment.slug,
            include_otp: include_otp,
            has_otp: credential[:otp].present?
          }
        )

        response = {
          key: secret.key,
          username: credential[:username],
          password: credential[:password],
          environment: environment.slug
        }

        if credential[:otp]
          response[:otp] = {
            code: credential[:otp][:code],
            expires_at: credential[:otp][:expires_at]&.iso8601,
            remaining_seconds: credential[:otp][:remaining_seconds]
          }
        end

        success(response)
      end
    end
  end
end
