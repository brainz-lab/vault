module Mcp
  module Tools
    class VerifyOtp < Base
      DESCRIPTION = "Verify an OTP code against a secret's OTP configuration."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the secret with OTP configured"
          },
          code: {
            type: "string",
            description: "The OTP code to verify"
          },
          environment: {
            type: "string",
            description: "Optional environment slug (defaults to development)"
          }
        },
        required: [ "key", "code" ]
      }.freeze

      def call(params)
        key = params[:key]
        code = params[:code]

        return error("key is required") unless key.present?
        return error("code is required") unless code.present?

        secret = project.secrets.active.find_by(key: key)
        return error("Secret not found: #{key}") unless secret
        return error("Secret does not support OTP") unless secret.otp_enabled?

        result = secret.verify_otp(environment, code)

        log_access(
          action: "mcp_verify_otp",
          secret: secret,
          details: {
            environment: environment.slug,
            valid: result[:valid],
            otp_type: secret.secret_type
          }
        )

        response = {
          key: secret.key,
          valid: result[:valid],
          environment: environment.slug
        }

        # Include drift info for TOTP if valid
        if result[:valid] && result[:drift]
          response[:drift] = result[:drift]
        end

        # Include new counter for HOTP if valid
        if result[:valid] && result[:new_counter]
          response[:new_counter] = result[:new_counter]
        end

        success(response)
      rescue ArgumentError => e
        error(e.message)
      end
    end
  end
end
