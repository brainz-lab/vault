module Otp
  class Verifier
    ALGORITHMS = {
      "sha1" => "SHA1",
      "sha256" => "SHA256",
      "sha512" => "SHA512"
    }.freeze

    # TOTP allows for clock drift - check ±1 period by default
    DEFAULT_TOTP_DRIFT = 1

    # HOTP look-ahead window - check next N codes
    DEFAULT_HOTP_LOOKAHEAD = 10

    class << self
      # Verify a TOTP code
      # drift_behind/drift_ahead: number of periods to allow for clock skew
      # Returns: { valid: Boolean, drift: Integer (periods off) }
      def verify_totp(secret, code, digits: 6, period: 30, algorithm: "sha1", drift_behind: DEFAULT_TOTP_DRIFT, drift_ahead: DEFAULT_TOTP_DRIFT)
        totp = ROTP::TOTP.new(
          secret,
          digits: digits,
          interval: period,
          digest: ALGORITHMS[algorithm] || "SHA1"
        )

        # Calculate drift window in seconds
        drift_seconds = [ drift_behind, drift_ahead ].max * period

        # verify_with_drift returns the timestamp or nil
        timestamp = totp.verify(code, drift_behind: drift_seconds, drift_ahead: drift_seconds)

        if timestamp
          # Calculate how many periods off the code was
          current_period = Time.current.to_i / period
          code_period = timestamp.to_i / period
          drift = code_period - current_period

          { valid: true, drift: drift }
        else
          { valid: false, drift: nil }
        end
      end

      # Verify an HOTP code with look-ahead window
      # Returns: { valid: Boolean, new_counter: Integer (if valid, counter to use next) }
      def verify_hotp(secret, code, counter:, digits: 6, algorithm: "sha1", lookahead: DEFAULT_HOTP_LOOKAHEAD)
        hotp = ROTP::HOTP.new(
          secret,
          digits: digits,
          digest: ALGORITHMS[algorithm] || "SHA1"
        )

        # Check counter and look-ahead window
        verification_counter = hotp.verify(code, counter, retries: lookahead)

        if verification_counter
          # Return new counter (one after the verified counter)
          { valid: true, new_counter: verification_counter + 1 }
        else
          { valid: false, new_counter: nil }
        end
      end

      # Strict verification - no drift allowed (for testing or high-security scenarios)
      def verify_totp_strict(secret, code, digits: 6, period: 30, algorithm: "sha1")
        verify_totp(secret, code, digits: digits, period: period, algorithm: algorithm, drift_behind: 0, drift_ahead: 0)
      end

      # Verify with custom drift window
      def verify_totp_with_window(secret, code, window:, digits: 6, period: 30, algorithm: "sha1")
        verify_totp(secret, code, digits: digits, period: period, algorithm: algorithm, drift_behind: window, drift_ahead: window)
      end
    end
  end
end
