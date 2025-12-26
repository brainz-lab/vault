class SsoController < ApplicationController
  # GET /sso/callback
  # Handle SSO callback from Platform
  def callback
    token = params[:token]
    return_to = params[:return_to] || dashboard_projects_path

    unless token.present?
      redirect_to ENV["BRAINZLAB_PLATFORM_URL"] || "http://platform.localhost:2999/login",
                  allow_other_host: true
      return
    end

    # Validate token with Platform
    result = validate_sso_token(token)

    if result[:valid]
      # Store session
      session[:user_id] = result[:user_id]
      session[:organization_id] = result[:organization_id]
      session[:email] = result[:email]
      session[:name] = result[:name]
      session[:expires_at] = 24.hours.from_now.to_i

      redirect_to return_to
    else
      redirect_to ENV["BRAINZLAB_PLATFORM_URL"] || "http://platform.localhost:2999/login",
                  allow_other_host: true
    end
  end

  private

  def validate_sso_token(token)
    return development_sso_result if Rails.env.development? && !platform_configured?

    response = platform_connection.post("/api/v1/sso/validate") do |req|
      req.headers["X-Service-Key"] = service_key
      req.body = { token: token }.to_json
    end

    if response.success?
      data = JSON.parse(response.body, symbolize_names: true)
      { valid: true }.merge(data)
    else
      { valid: false }
    end
  rescue Faraday::Error
    { valid: false }
  end

  def platform_connection
    @platform_connection ||= Faraday.new(platform_url) do |f|
      f.headers["Content-Type"] = "application/json"
      f.adapter Faraday.default_adapter
    end
  end

  def platform_url
    ENV["BRAINZLAB_PLATFORM_URL"] || "http://localhost:2999"
  end

  def service_key
    ENV["SERVICE_KEY"] || "dev_service_key"
  end

  def platform_configured?
    ENV["BRAINZLAB_PLATFORM_URL"].present?
  end

  def development_sso_result
    {
      valid: true,
      user_id: SecureRandom.uuid,
      organization_id: SecureRandom.uuid,
      email: "dev@localhost",
      name: "Developer"
    }
  end

  def dashboard_projects_path
    "/dashboard"
  end
end
