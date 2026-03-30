# frozen_string_literal: true

require "resolv"

module Connectors
  module Manifest
    # HTTP client that executes requests defined in Airbyte manifest YAMLs.
    #
    # Security controls:
    # - HTTPS-only (no plaintext HTTP)
    # - SSRF prevention (blocks private IPs: localhost, 10.x, 172.16-31.x, 192.168.x)
    # - Configurable timeouts
    # - Response size limit (10MB)
    #
    class HttpRequester
      MAX_RESPONSE_SIZE = 10 * 1024 * 1024 # 10MB
      DEFAULT_TIMEOUT = 30
      PRIVATE_IP_PATTERN = /\A(127\.|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|0\.|169\.254\.|::1|fe80:|fc00:|fd00:)/i

      def initialize(requester_config, interpolator:, authenticator:, error_handler: nil)
        @config = requester_config || {}
        @interpolator = interpolator
        @authenticator = authenticator
        @error_handler = error_handler || ErrorHandler.new
      end

      # Execute an HTTP request and return parsed response body.
      def fetch(extra_params = {})
        url = build_url(extra_params)
        validate_url!(url)

        handler = @error_handler
        handler.with_retry do
          response = execute_request(url, extra_params)
          handle_response(response, handler)
        end
      end

      private

      def build_url(extra_params)
        base = @interpolator.interpolate(
          @config["url_base"] || @config[:url_base] || @config["url"] || @config[:url] || ""
        )
        path = @interpolator.interpolate(
          @config["path"] || @config[:path] || ""
        )

        url = base.to_s.chomp("/")
        url += "/#{path.to_s.sub(%r{\A/}, '')}" if path.present?
        url
      end

      def validate_url!(url)
        uri = URI.parse(url)

        unless uri.scheme == "https"
          raise Connectors::SecurityError, "Only HTTPS URLs are allowed (got: #{uri.scheme})"
        end

        begin
          resolved_ip = Resolv.getaddress(uri.host)
          if resolved_ip.match?(PRIVATE_IP_PATTERN)
            raise Connectors::SecurityError, "SSRF blocked: #{uri.host} resolves to private IP #{resolved_ip}"
          end
        rescue Resolv::ResolvError
          raise Connectors::Error, "DNS resolution failed for #{uri.host}"
        end
      end

      def execute_request(url, extra_params)
        method = (@config["http_method"] || @config[:http_method] || "GET").upcase

        connection = Faraday.new do |f|
          f.request :json if method != "GET"
          f.response :json, content_type: /\bjson$/
          f.options.timeout = @config["timeout"] || DEFAULT_TIMEOUT
          f.options.open_timeout = 10
        end

        response = connection.run_request(method.downcase.to_sym, url, nil, nil) do |req|
          @authenticator.apply(req)
          apply_headers(req)
          apply_params(req, extra_params)
          apply_body(req) if %w[POST PUT PATCH].include?(method)
        end

        response
      end

      def apply_headers(request)
        headers = @config["request_headers"] || @config[:request_headers]
        return unless headers.is_a?(Hash)

        headers.each do |key, value|
          request.headers[key] = @interpolator.interpolate(value)
        end
      end

      def apply_params(request, extra_params)
        params = @config["request_parameters"] || @config[:request_parameters] || {}
        params = @interpolator.interpolate(params) if params.is_a?(Hash)

        merged = params.merge(extra_params)
        merged.each do |key, value|
          request.params[key.to_s] = value unless value.nil?
        end
      end

      def apply_body(request)
        body = @config["request_body_json"] || @config[:request_body_json]
        return unless body.is_a?(Hash)

        request.body = @interpolator.interpolate(body)
      end

      def handle_response(response, handler)
        if response.status == 429
          raise Connectors::RateLimitError, "Rate limited (HTTP 429)"
        end

        if handler.should_fail?(response.status, response.body)
          raise Connectors::Error, "Request failed with HTTP #{response.status}: #{truncate(response.body.to_s)}"
        end

        if handler.should_retry?(response.status, response.body)
          raise Connectors::RateLimitError, "Retryable error (HTTP #{response.status})"
        end

        unless response.success?
          raise Connectors::Error, "HTTP #{response.status}: #{truncate(response.body.to_s)}"
        end

        body = response.body
        if body.is_a?(String) && body.bytesize > MAX_RESPONSE_SIZE
          raise Connectors::Error, "Response too large (#{body.bytesize} bytes, max #{MAX_RESPONSE_SIZE})"
        end

        body
      end

      def truncate(str, max: 500)
        str.length > max ? "#{str[0..max]}..." : str
      end
    end
  end
end
