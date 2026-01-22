module Mcp
  module Tools
    class GenerateOtp < Base
      DESCRIPTION = "Generate an OTP code for a secret that has OTP configured."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the secret with OTP configured"
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
        return error("Secret does not support OTP") unless secret.otp_enabled?

        otp_result = secret.generate_otp(environment)

        log_access(
          action: "mcp_generate_otp",
          secret: secret,
          details: {
            environment: environment.slug,
            otp_type: secret.secret_type
          }
        )

        response = {
          key: secret.key,
          code: otp_result[:code],
          environment: environment.slug
        }

        # Add time-based info for TOTP
        if otp_result[:expires_at]
          response[:expires_at] = otp_result[:expires_at].iso8601
          response[:remaining_seconds] = otp_result[:remaining_seconds]
        end

        # Add counter info for HOTP
        if otp_result[:counter]
          response[:counter] = otp_result[:counter]
        end

        success(response)
      rescue ArgumentError => e
        error(e.message)
      end
    end
  end
end
