module Oauth
  class StateManager
    STATE_TTL = 15.minutes.to_i
    STATE_PREFIX = "vault:oauth:state:"
    TOKEN_BYTES = 32

    class InvalidStateError < StandardError; end
    class ExpiredStateError < StandardError; end

    class << self
      def generate(project_id:, connector_id:, user_id:, return_to: nil, popup: nil)
        token = SecureRandom.hex(TOKEN_BYTES)

        payload = {
          project_id: project_id,
          connector_id: connector_id,
          user_id: user_id,
          return_to: return_to,
          popup: popup,
          created_at: Time.current.iso8601
        }.to_json

        redis.set(state_key(token), payload, ex: STATE_TTL)

        Rails.logger.info "[Oauth::StateManager] Generated state token for project=#{project_id} connector=#{connector_id}"

        token
      end

      def consume!(token)
        key = state_key(token)

        payload = redis.multi do |tx|
          tx.get(key)
          tx.del(key)
        end

        raw = payload[0]

        if raw.nil?
          raise ExpiredStateError, "OAuth state token is invalid or expired"
        end

        data = JSON.parse(raw, symbolize_names: true)

        Rails.logger.info "[Oauth::StateManager] Consumed state token for project=#{data[:project_id]} connector=#{data[:connector_id]}"

        data
      end

      private

      def state_key(token)
        "#{STATE_PREFIX}#{token}"
      end

      def redis
        @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
      end
    end
  end
end
