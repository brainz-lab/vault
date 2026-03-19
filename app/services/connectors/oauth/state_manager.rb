# frozen_string_literal: true

module Connectors
  module Oauth
    class StateManager
      EXPIRATION = 10.minutes
      SEPARATOR = "."

      def self.generate(payload)
        new.generate(payload)
      end

      def self.validate!(state)
        new.validate!(state)
      end

      def generate(payload)
        payload[:issued_at] = Time.current.to_i
        encoded = Base64.urlsafe_encode64(payload.to_json, padding: false)
        signature = sign(encoded)
        "#{encoded}#{SEPARATOR}#{signature}"
      end

      def validate!(state)
        encoded, signature = state.to_s.split(SEPARATOR, 2)
        raise Connectors::AuthenticationError, "Invalid OAuth state" if encoded.blank? || signature.blank?
        raise Connectors::AuthenticationError, "Invalid OAuth state signature" unless ActiveSupport::SecurityUtils.secure_compare(sign(encoded), signature)

        payload = JSON.parse(Base64.urlsafe_decode64(encoded), symbolize_names: true)
        issued_at = Time.at(payload[:issued_at])
        raise Connectors::AuthenticationError, "OAuth state expired" if issued_at < EXPIRATION.ago

        payload
      end

      private

      def sign(data)
        OpenSSL::HMAC.hexdigest("SHA256", signing_key, data)
      end

      def signing_key
        Rails.application.secret_key_base
      end
    end
  end
end
