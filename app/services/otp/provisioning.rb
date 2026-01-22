module Otp
  class Provisioning
    ALGORITHMS = {
      "sha1" => "SHA1",
      "sha256" => "SHA256",
      "sha512" => "SHA512"
    }.freeze

    class << self
      # Generate a new OTP secret with provisioning URI
      # Returns: { secret: String, uri: String }
      def create_totp(account_name:, issuer: nil, digits: 6, period: 30, algorithm: "sha1")
        secret = Generator.generate_secret

        totp = ROTP::TOTP.new(
          secret,
          digits: digits,
          interval: period,
          digest: ALGORITHMS[algorithm] || "SHA1",
          issuer: issuer
        )

        uri = totp.provisioning_uri(account_name)

        {
          secret: secret,
          uri: uri,
          type: "totp",
          digits: digits,
          period: period,
          algorithm: algorithm,
          issuer: issuer,
          account_name: account_name
        }
      end

      # Generate a new HOTP secret with provisioning URI
      # Returns: { secret: String, uri: String, initial_counter: Integer }
      def create_hotp(account_name:, issuer: nil, digits: 6, algorithm: "sha1", initial_counter: 0)
        secret = Generator.generate_secret

        hotp = ROTP::HOTP.new(
          secret,
          digits: digits,
          digest: ALGORITHMS[algorithm] || "SHA1",
          issuer: issuer
        )

        uri = hotp.provisioning_uri(account_name, initial_counter)

        {
          secret: secret,
          uri: uri,
          type: "hotp",
          digits: digits,
          algorithm: algorithm,
          issuer: issuer,
          account_name: account_name,
          initial_counter: initial_counter
        }
      end

      # Generate provisioning URI for an existing TOTP secret
      def totp_uri(secret, account_name:, issuer: nil, digits: 6, period: 30, algorithm: "sha1")
        totp = ROTP::TOTP.new(
          secret,
          digits: digits,
          interval: period,
          digest: ALGORITHMS[algorithm] || "SHA1",
          issuer: issuer
        )

        totp.provisioning_uri(account_name)
      end

      # Generate provisioning URI for an existing HOTP secret
      def hotp_uri(secret, account_name:, counter:, issuer: nil, digits: 6, algorithm: "sha1")
        hotp = ROTP::HOTP.new(
          secret,
          digits: digits,
          digest: ALGORITHMS[algorithm] || "SHA1",
          issuer: issuer
        )

        hotp.provisioning_uri(account_name, counter)
      end

      # Parse an otpauth:// URI and extract parameters
      # Returns: { type: "totp"|"hotp", secret: String, issuer: String, account_name: String, ... }
      def parse_uri(uri)
        return nil unless uri.start_with?("otpauth://")

        parsed = URI.parse(uri)
        type = parsed.host # "totp" or "hotp"
        path = URI.decode_www_form_component(parsed.path[1..]) # Remove leading /
        params = URI.decode_www_form(parsed.query || "").to_h

        # Path format: "issuer:account" or just "account"
        if path.include?(":")
          issuer_from_path, account_name = path.split(":", 2)
        else
          issuer_from_path = nil
          account_name = path
        end

        {
          type: type,
          secret: params["secret"],
          issuer: params["issuer"] || issuer_from_path,
          account_name: account_name,
          digits: (params["digits"] || "6").to_i,
          period: (params["period"] || "30").to_i,
          algorithm: (params["algorithm"] || "SHA1").downcase,
          counter: params["counter"]&.to_i
        }
      rescue URI::InvalidURIError
        nil
      end

      # Validate a provisioning URI
      def valid_uri?(uri)
        parsed = parse_uri(uri)
        return false unless parsed

        # Must have secret and valid type
        parsed[:secret].present? && %w[totp hotp].include?(parsed[:type])
      end
    end
  end
end
