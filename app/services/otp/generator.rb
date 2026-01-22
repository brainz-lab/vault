module Otp
  class Generator
    ALGORITHMS = {
      "sha1" => "SHA1",
      "sha256" => "SHA256",
      "sha512" => "SHA512"
    }.freeze

    class << self
      # Generate a TOTP (Time-based One-Time Password) code
      # Returns: { code: "123456", expires_at: Time, remaining_seconds: Integer }
      def generate_totp(secret, digits: 6, period: 30, algorithm: "sha1")
        totp = ROTP::TOTP.new(
          secret,
          digits: digits,
          interval: period,
          digest: ALGORITHMS[algorithm] || "SHA1"
        )

        code = totp.now
        current_time = Time.current
        period_start = (current_time.to_i / period) * period
        expires_at = Time.at(period_start + period)
        remaining_seconds = (expires_at - current_time).to_i

        {
          code: code,
          expires_at: expires_at,
          remaining_seconds: remaining_seconds
        }
      end

      # Generate an HOTP (HMAC-based One-Time Password) code
      # Note: Counter should be incremented after successful verification
      # Returns: { code: "123456", counter: Integer }
      def generate_hotp(secret, counter:, digits: 6, algorithm: "sha1")
        hotp = ROTP::HOTP.new(
          secret,
          digits: digits,
          digest: ALGORITHMS[algorithm] || "SHA1"
        )

        code = hotp.at(counter)

        {
          code: code,
          counter: counter
        }
      end

      # Generate a random base32 OTP secret
      # length: number of bytes (default 20 = 160 bits, standard for TOTP)
      def generate_secret(length: 20)
        ROTP::Base32.random_base32(length)
      end

      # Check if a secret is valid base32
      def valid_secret?(secret)
        return false if secret.blank?

        # ROTP uses base32 encoding
        ROTP::Base32.decode(secret)
        true
      rescue
        false
      end
    end
  end
end
