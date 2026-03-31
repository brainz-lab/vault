# frozen_string_literal: true

module Connectors
  module Manifest
    # Handles HTTP errors with retry and backoff strategies.
    #
    # Maps to Airbyte's DefaultErrorHandler with:
    # - Configurable max_retries
    # - Backoff strategies (constant, exponential)
    # - Response filters (retry on specific status codes)
    #
    class ErrorHandler
      DEFAULT_MAX_RETRIES = 3
      DEFAULT_BACKOFF_SECONDS = 5
      RETRYABLE_STATUS_CODES = [ 429, 500, 502, 503, 504 ].freeze

      def initialize(config = {})
        @max_retries = config["max_retries"] || config[:max_retries] || DEFAULT_MAX_RETRIES
        @backoff_strategy = parse_backoff(config["backoff_strategies"] || config[:backoff_strategies])
        @response_filters = config["response_filters"] || config[:response_filters] || []
      end

      def with_retry
        attempt = 0
        begin
          yield
        rescue Connectors::RateLimitError, Faraday::ServerError, Faraday::TimeoutError => e
          attempt += 1
          raise if attempt > @max_retries

          sleep_duration = backoff_duration(attempt)
          sleep(sleep_duration) if sleep_duration > 0
          retry
        end
      end

      def should_retry?(status, _body = nil)
        return true if RETRYABLE_STATUS_CODES.include?(status)

        @response_filters.any? do |filter|
          filter_codes = filter["http_codes"] || filter[:http_codes] || []
          filter_action = filter["action"] || filter[:action]
          filter_codes.include?(status) && filter_action == "RETRY"
        end
      end

      def should_fail?(status, _body = nil)
        @response_filters.any? do |filter|
          filter_codes = filter["http_codes"] || filter[:http_codes] || []
          filter_action = filter["action"] || filter[:action]
          filter_codes.include?(status) && filter_action == "FAIL"
        end
      end

      private

      def parse_backoff(strategies)
        return { type: :exponential, factor: DEFAULT_BACKOFF_SECONDS } unless strategies.is_a?(Array) && strategies.any?

        strategy = strategies.first
        type = strategy["type"] || strategy[:type]

        case type
        when "ConstantBackoffStrategy"
          { type: :constant, seconds: strategy["backoff_time_in_seconds"] || DEFAULT_BACKOFF_SECONDS }
        when "ExponentialBackoffStrategy"
          { type: :exponential, factor: strategy["factor"] || 2 }
        else
          { type: :exponential, factor: DEFAULT_BACKOFF_SECONDS }
        end
      end

      def backoff_duration(attempt)
        case @backoff_strategy[:type]
        when :constant
          @backoff_strategy[:seconds]
        when :exponential
          @backoff_strategy[:factor] ** (attempt - 1)
        else
          DEFAULT_BACKOFF_SECONDS
        end
      end
    end
  end
end
