# frozen_string_literal: true

# Client for validating API keys against Platform
# Enables unified authentication across all BrainzLab products
class PlatformClient
  PLATFORM_URL = ENV.fetch("PLATFORM_URL", "https://platform.brainzlab.ai")
  TIMEOUT = 5

  # Cache durations
  VALID_KEY_CACHE_TTL = 5.minutes
  INVALID_KEY_CACHE_TTL = 30.seconds  # Short TTL for invalid keys to allow quick retry after fix

  class ValidationResult
    attr_reader :valid, :project_id, :project_slug, :organization_id,
                :organization_slug, :environment, :plan, :scopes, :error

    def initialize(data)
      @valid = data[:valid]
      @project_id = data[:project_id]
      @project_slug = data[:project_slug]
      @organization_id = data[:organization_id]
      @organization_slug = data[:organization_slug]
      @environment = data[:environment]
      @plan = data[:plan]
      @scopes = data[:scopes] || []
      @error = data[:error]
    end

    def valid?
      @valid == true
    end
  end

  class << self
    # Validate an API key against Platform (cached)
    # @param key [String] The API key to validate (sk_live_xxx or sk_test_xxx)
    # @return [ValidationResult] Result with project info if valid
    def validate_key(key)
      return ValidationResult.new(valid: false, error: "Key required") if key.blank?

      # Check cache first
      cache_key = "platform_key_validation:#{Digest::SHA256.hexdigest(key)}"
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?

      result = validate_key_uncached(key)

      # Cache the result (shorter TTL for invalid keys)
      ttl = result.valid? ? VALID_KEY_CACHE_TTL : INVALID_KEY_CACHE_TTL
      Rails.cache.write(cache_key, result, expires_in: ttl)

      result
    end

    # Validate without caching (for internal use)
    def validate_key_uncached(key)
      uri = URI.parse("#{PLATFORM_URL}/api/v1/keys/validate")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "vault/#{Rails.application.config.version rescue '1.0'}"
      request.body = { key: key }.to_json

      response = execute_request(uri, request)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body, symbolize_names: true)
        ValidationResult.new(data)
      else
        error = begin
          JSON.parse(response.body)["error"]
        rescue
          "Platform validation failed"
        end
        ValidationResult.new(valid: false, error: error)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.warn "[PlatformClient] Timeout validating key: #{e.message}"
      ValidationResult.new(valid: false, error: "Platform timeout")
    rescue StandardError => e
      Rails.logger.error "[PlatformClient] Error validating key: #{e.message}"
      ValidationResult.new(valid: false, error: "Platform error")
    end

    # Find or create a local project from Platform validation
    # Handles key regeneration by updating the api_key if it changed
    # @param result [ValidationResult] Successful validation result
    # @param api_key [String] The API key used for validation
    # @return [Project] Local project record
    def find_or_create_project(result, api_key)
      return nil unless result.valid?

      project = Project.find_by(platform_project_id: result.project_id)

      if project
        # Sync: Update key if regenerated in Platform
        if project.api_key != api_key
          project.update!(api_key: api_key, ingest_key: api_key)
          Rails.logger.info "[PlatformClient] Synced regenerated key for project #{project.name}"
        end
        return project
      end

      # Create new project
      Project.create!(
        platform_project_id: result.project_id,
        name: result.project_slug || "Project #{result.project_id}",
        api_key: api_key,
        ingest_key: api_key,
        environment: result.environment || "production"
      )
    rescue ActiveRecord::RecordNotUnique
      # Race condition - another request created it, retry lookup
      Project.find_by(platform_project_id: result.project_id)
    end

    # Track usage metrics (for billing)
    def track_usage(project_id:, product:, metric:, count:)
      return unless platform_configured?

      TrackUsageJob.perform_later(
        project_id: project_id,
        product: product,
        metric: metric,
        count: count
      )
    end

    private

    def execute_request(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http.request(request)
    end

    def platform_configured?
      ENV["PLATFORM_URL"].present?
    end
  end
end
