module Mcp
  module Tools
    class ImportCredentials < Base
      DESCRIPTION = "Batch import credentials from Apple Passwords CSV format or structured array."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          credentials: {
            type: "array",
            description: "Array of credential objects to import",
            items: {
              type: "object",
              properties: {
                title: { type: "string", description: "Title/name of the credential" },
                url: { type: "string", description: "URL or domain" },
                username: { type: "string", description: "Username/email" },
                password: { type: "string", description: "Password" },
                notes: { type: "string", description: "Optional notes" },
                otp_auth: { type: "string", description: "OTPAuth URL (otpauth://totp/...)" }
              },
              required: %w[ username password ]
            }
          },
          csv: {
            type: "string",
            description: "Apple Passwords CSV content (alternative to credentials array)"
          },
          environment: {
            type: "string",
            description: "Environment slug (default: development)"
          },
          skip_existing: {
            type: "boolean",
            description: "Skip credentials that already exist (default: true)"
          },
          dry_run: {
            type: "boolean",
            description: "Validate without saving (default: false)"
          }
        }
      }.freeze

      def call(params)
        credentials = params[:credentials] || parse_csv(params[:csv])
        return error("No credentials provided") if credentials.blank?

        skip_existing = params[:skip_existing] != false
        dry_run = params[:dry_run] == true

        results = {
          imported: [],
          skipped: [],
          errors: []
        }

        credentials.each do |cred|
          result = import_credential(cred, skip_existing: skip_existing, dry_run: dry_run)

          case result[:status]
          when :imported
            results[:imported] << result[:key]
          when :skipped
            results[:skipped] << { key: result[:key], reason: result[:reason] }
          when :error
            results[:errors] << { key: result[:key], error: result[:error] }
          end
        end

        log_access(
          action: "mcp_import_credentials",
          secret: nil,
          details: {
            environment: environment.slug,
            imported_count: results[:imported].size,
            skipped_count: results[:skipped].size,
            error_count: results[:errors].size,
            dry_run: dry_run
          }
        )

        success(
          imported: results[:imported].size,
          skipped: results[:skipped].size,
          errors: results[:errors].size,
          details: results
        )
      end

      private

      def parse_csv(csv_content)
        return [] if csv_content.blank?

        require "csv"
        parsed = CSV.parse(csv_content, headers: true)

        parsed.map do |row|
          {
            title: row["Title"],
            url: row["URL"],
            username: row["Username"],
            password: row["Password"],
            notes: row["Notes"],
            otp_auth: row["OTPAuth"]
          }
        end
      rescue CSV::MalformedCSVError => e
        []
      end

      def import_credential(cred, skip_existing:, dry_run:)
        # Determine key from URL or title
        raw_key = cred[:url].presence || cred[:title].presence || cred[:username]
        key = Secret.normalize_key(raw_key)

        return { status: :error, key: key, error: "No username" } if cred[:username].blank?
        return { status: :error, key: key, error: "No password" } if cred[:password].blank?

        existing = project.secrets.find_by(key: key)

        if existing && skip_existing
          return { status: :skipped, key: key, reason: "already exists" }
        end

        return { status: :imported, key: key } if dry_run

        secret = existing || project.secrets.new(key: key)

        # Store original URL
        secret.url = cred[:url] if cred[:url].present?
        secret.description = cred[:title].presence
        secret.notes = cred[:notes] if cred[:notes].present?

        # Parse OTPAuth URL if present
        otp_params = parse_otp_auth(cred[:otp_auth])

        ActiveRecord::Base.transaction do
          if otp_params
            secret.set_credential_with_otp(
              environment,
              username: cred[:username],
              password: cred[:password],
              otp_secret: otp_params[:secret],
              otp_type: otp_params[:type] || "totp",
              otp_algorithm: otp_params[:algorithm] || "sha1",
              otp_digits: otp_params[:digits] || 6,
              otp_period: otp_params[:period] || 30,
              otp_issuer: otp_params[:issuer],
              note: "Imported from Apple Passwords"
            )
          else
            secret.save!
            secret.set_credential(
              environment,
              username: cred[:username],
              password: cred[:password],
              note: "Imported from Apple Passwords"
            )
          end
        end

        { status: :imported, key: key }
      rescue => e
        { status: :error, key: key, error: e.message }
      end

      def parse_otp_auth(otp_auth_url)
        return nil if otp_auth_url.blank?

        # Parse otpauth://totp/Label?secret=XXX&issuer=YYY&algorithm=SHA1&digits=6&period=30
        uri = URI.parse(otp_auth_url)
        return nil unless uri.scheme == "otpauth"

        params = URI.decode_www_form(uri.query || "").to_h

        {
          type: uri.host, # totp or hotp
          secret: params["secret"],
          issuer: params["issuer"],
          algorithm: params["algorithm"]&.downcase,
          digits: params["digits"]&.to_i,
          period: params["period"]&.to_i
        }
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
