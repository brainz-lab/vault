class HealthController < ApplicationController
  def show
    checks = {
      database: check_database,
      redis: check_redis,
      encryption: check_encryption
    }

    status = checks.values.all? { |c| c[:status] == "ok" } ? :ok : :service_unavailable

    render json: {
      status: status == :ok ? "healthy" : "unhealthy",
      service: "vault",
      version: ENV["APP_VERSION"] || "dev",
      checks: checks,
      timestamp: Time.current.iso8601
    }, status: status
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue => e
    { status: "error", message: e.message }
  end

  def check_redis
    redis = Redis.new(url: ENV["REDIS_URL"])
    redis.ping
    { status: "ok" }
  rescue => e
    { status: "error", message: e.message }
  end

  def check_encryption
    Encryption::KeyManager.master_key_configured? ? { status: "ok" } : { status: "warning", message: "Master key not configured" }
  rescue => e
    { status: "error", message: e.message }
  end
end
