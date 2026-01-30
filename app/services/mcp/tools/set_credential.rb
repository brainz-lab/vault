module Mcp
  module Tools
    class SetCredential < Base
      DESCRIPTION = "Create or update a credential (username/password) with optional OTP secret."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key: {
            type: "string",
            description: "The key/name of the credential secret. Can be a URL (e.g., 'hey.com') which will be normalized to uppercase (HEY_COM)"
          },
          url: {
            type: "string",
            description: "Optional URL to store with the credential (useful when key is normalized from URL)"
          },
          username: {
            type: "string",
            description: "The username/email for the credential"
          },
          password: {
            type: "string",
            description: "The password for the credential"
          },
          environment: {
            type: "string",
            description: "Optional environment slug (defaults to development)"
          },
          otp_secret: {
            type: "string",
            description: "Optional base32-encoded OTP secret (e.g., from authenticator app setup)"
          },
          otp_type: {
            type: "string",
            enum: [ "totp", "hotp" ],
            description: "OTP type: totp (time-based, default) or hotp (counter-based)"
          },
          otp_algorithm: {
            type: "string",
            enum: [ "sha1", "sha256", "sha512" ],
            description: "OTP algorithm (default: sha1)"
          },
          otp_digits: {
            type: "integer",
            description: "Number of OTP digits (default: 6)"
          },
          otp_period: {
            type: "integer",
            description: "TOTP period in seconds (default: 30)"
          },
          otp_issuer: {
            type: "string",
            description: "Optional issuer name for the OTP"
          },
          description: {
            type: "string",
            description: "Optional description of the credential"
          },
          notes: {
            type: "string",
            description: "Optional notes (e.g., recovery codes, security questions)"
          },
          note: {
            type: "string",
            description: "Optional note for this version"
          }
        },
        required: [ "key", "username", "password" ]
      }.freeze

      def call(params)
        raw_key = params[:key]
        username = params[:username]
        password = params[:password]

        return error("key is required") unless raw_key.present?
        return error("username is required") unless username.present?
        return error("password is required") unless password.present?

        # Normalize key (e.g., "hey.com" -> "HEY_COM")
        key = Secret.normalize_key(raw_key)

        secret = project.secrets.find_or_initialize_by(key: key)
        was_new = secret.new_record?

        # Store URL if provided or if key was a URL
        if params[:url].present?
          secret.url = params[:url]
        elsif raw_key != key && raw_key.include?(".")
          # Key was normalized from a URL/domain, store original
          secret.url = raw_key.start_with?("http") ? raw_key : "https://#{raw_key}"
        end

        if params[:description].present?
          secret.description = params[:description]
        end

        if params[:notes].present?
          secret.notes = params[:notes]
        end

        ActiveRecord::Base.transaction do
          if params[:otp_secret].present?
            # Validate OTP secret
            unless Otp::Generator.valid_secret?(params[:otp_secret])
              raise ArgumentError, "Invalid base32 OTP secret"
            end

            secret.set_credential_with_otp(
              environment,
              username: username,
              password: password,
              otp_secret: params[:otp_secret],
              otp_type: params[:otp_type] || "totp",
              otp_algorithm: params[:otp_algorithm] || "sha1",
              otp_digits: params[:otp_digits] || 6,
              otp_period: params[:otp_period] || 30,
              otp_issuer: params[:otp_issuer],
              user: nil,
              note: params[:note]
            )
          else
            secret.save!
            secret.set_credential(
              environment,
              username: username,
              password: password,
              user: nil,
              note: params[:note]
            )
          end
        end

        log_access(
          action: was_new ? "mcp_create_credential" : "mcp_update_credential",
          secret: secret,
          details: {
            environment: environment.slug,
            has_otp: params[:otp_secret].present?
          }
        )

        success(
          key: secret.key,
          created: was_new,
          has_otp: params[:otp_secret].present?,
          environment: environment.slug,
          version: secret.current_version_number
        )
      rescue ArgumentError => e
        error(e.message)
      end
    end
  end
end
