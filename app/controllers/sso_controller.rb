class SsoController < ActionController::Base
  include ActionController::Cookies

  # Disable Turbo Drive for SSO callback to prevent caching issues
  # This ensures the redirect after authentication works correctly
  skip_before_action :verify_authenticity_token, raise: false

  # GET /sso/callback
  # Handle SSO callback from Platform
  def callback
    token = params[:token]
    return_to = params[:return_to]

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

      # Sync all user's projects from Platform
      sync_projects_from_platform(token)

      # Ensure at least the current project exists (fallback if full sync failed)
      ensure_project_exists(result)

      return_to ||= project_redirect_path(result) || dashboard_projects_path

      # Use client-side redirect to completely bypass Turbo Drive
      # This prevents blank page issues after SSO authentication
      render html: %{
        <!DOCTYPE html>
        <html>
        <head>
          <meta http-equiv="refresh" content="0;url=#{ERB::Util.html_escape(return_to)}">
          <script>window.location.replace("#{ERB::Util.html_escape(return_to)}");</script>
        </head>
        <body>Redirecting...</body>
        </html>
      }.html_safe, layout: false
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

  def sync_projects_from_platform(sso_token)
    projects_data = fetch_user_projects(sso_token)
    return unless projects_data

    platform_ids = projects_data.map { |d| d["id"].to_s }

    projects_data.each do |data|
      project = Project.find_or_initialize_by(platform_project_id: data["id"].to_s)
      project.name = data["name"]
      project.environment = data["environment"] || "production"
      project.archived_at = nil
      project.save!
    end

    Project.where.not(platform_project_id: [nil, ""])
           .where.not(platform_project_id: platform_ids)
           .where(archived_at: nil)
           .update_all(archived_at: Time.current)

    Rails.logger.info("[SSO] Synced #{projects_data.count} projects from Platform")
  rescue => e
    Rails.logger.error("[SSO] Project sync failed: #{e.message}")
  end

  # Fallback: ensure at least the current project exists from SSO validation data
  def ensure_project_exists(user_info)
    return unless user_info[:project_id].present?

    project = Project.find_or_initialize_by(platform_project_id: user_info[:project_id].to_s)
    return if project.persisted? # Already exists

    project.name = user_info[:project_slug] || "Project #{user_info[:project_id]}"
    project.environment = "production"
    project.save!
    Rails.logger.info("[SSO] Created project from SSO validation: #{project.name}")
  rescue => e
    Rails.logger.error("[SSO] ensure_project_exists failed: #{e.message}")
  end

  def fetch_user_projects(sso_token)
    uri = URI("#{platform_url}/api/v1/user/projects")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.path)
    request["Accept"] = "application/json"
    request["X-SSO-Token"] = sso_token

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)["projects"]
    else
      nil
    end
  rescue => e
    Rails.logger.error("[SSO] fetch_user_projects failed: #{e.message}")
    nil
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

  def project_redirect_path(result)
    return nil unless result[:project_id].present?
    project = Project.find_by(platform_project_id: result[:project_id].to_s)
    return nil unless project
    "/dashboard/projects/#{project.id}"
  end

  def dashboard_projects_path
    "/dashboard"
  end
end
