module Connectors
  module Native
    class Base
      def initialize(credentials)
        @credentials = credentials || {}
      end

      def execute(action, **params)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      def self.actions
        []
      end

      def self.piece_name
        raise NotImplementedError
      end

      def self.display_name
        piece_name.titleize
      end

      def self.description
        ""
      end

      def self.category
        "other"
      end

      def self.auth_type
        "NONE"
      end

      def self.auth_schema
        {}
      end

      def self.logo_url
        nil
      end

      protected

      attr_reader :credentials

      # Validate that a URL is safe for outbound requests (no SSRF).
      # Requires HTTPS and rejects private/internal IPs.
      def validate_base_url!(url, label: "base_url")
        uri = URI.parse(url)
        raise Connectors::SecurityError, "#{label} must use HTTPS" unless uri.scheme == "https"

        host = uri.host&.downcase
        raise Connectors::SecurityError, "#{label} has no host" if host.blank?

        # Reject localhost and loopback
        raise Connectors::SecurityError, "#{label} cannot target localhost" if %w[localhost 127.0.0.1 ::1 0.0.0.0].include?(host)

        # Reject private IP ranges via DNS resolution
        begin
          ip = IPAddr.new(Resolv.getaddress(host))
          if ip.private? || ip.loopback? || ip.link_local?
            raise Connectors::SecurityError, "#{label} resolves to a private/internal IP"
          end
        rescue Resolv::ResolvError
          # Can't resolve — allow (may be valid internal DNS in some setups)
        rescue IPAddr::InvalidAddressError
          # Not an IP — allow
        end

        url
      end

      # Validate a webhook/callback URL for safety
      def validate_webhook_url!(url, label: "url")
        raise Connectors::Error, "#{label} is required" if url.blank?

        uri = URI.parse(url)
        raise Connectors::SecurityError, "#{label} must use HTTPS" unless uri.scheme == "https"

        host = uri.host&.downcase
        raise Connectors::SecurityError, "#{label} cannot target localhost" if %w[localhost 127.0.0.1 ::1 0.0.0.0].include?(host)

        begin
          ip = IPAddr.new(Resolv.getaddress(host))
          raise Connectors::SecurityError, "#{label} targets a private IP" if ip.private? || ip.loopback? || ip.link_local?
        rescue Resolv::ResolvError, IPAddr::InvalidAddressError
          # Allow
        end

        url
      end

      # Validate a domain string (e.g., mystore.myshopify.com)
      def validate_domain!(domain, allowed_pattern: nil, label: "domain")
        raise Connectors::Error, "#{label} is required" if domain.blank?
        raise Connectors::SecurityError, "#{label} contains invalid characters" unless domain.match?(/\A[a-zA-Z0-9._-]+\z/)

        if allowed_pattern && !domain.match?(allowed_pattern)
          raise Connectors::SecurityError, "#{label} does not match expected pattern"
        end

        domain
      end
    end
  end
end
