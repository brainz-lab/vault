class OauthController < ActionController::Base
  include ActionController::Cookies

  skip_before_action :verify_authenticity_token, raise: false
  before_action :authenticate_request!, only: [:authorize]

  # GET /oauth/authorize
  # Initiates OAuth flow: builds state, redirects to provider
  def authorize
    # Resolve project: try Vault ID first, then platform_project_id (auto-create)
    project = Project.find_by(id: params[:project_id]) ||
              Project.find_or_create_for_platform!(
                platform_project_id: params[:project_id],
                name: params[:project_name] || "Project #{params[:project_id].to_s.first(8)}"
              )

    # Resolve connector: by UUID or piece_name
    cid = params[:connector_id]
    connector = if cid&.match?(/\A[0-9a-f-]{36}\z/)
      Connector.find(cid)
    else
      Connector.find_by!(piece_name: cid)
    end

    unless connector.oauth2?
      redirect_to_error("Connector '#{connector.display_name}' does not support OAuth2")
      return
    end

    provider = Oauth::ProviderFactory.new(connector, project: project)

    pkce = provider.pkce_enabled? ? provider.generate_pkce : {}
    redirect_uri = oauth_callback_url

    state = Oauth::StateManager.generate(
      project_id: project.id,
      connector_id: connector.id,
      user_id: current_oauth_user_id,
      return_to: params[:return_to]
    )

    if pkce.present?
      store_pkce_verifier(state, pkce[:code_verifier])
    end

    auth_url = provider.authorization_url(
      state: state,
      redirect_uri: redirect_uri,
      code_challenge: pkce[:code_challenge],
      code_challenge_method: pkce[:code_challenge_method]
    )

    Rails.logger.info "[OauthController] Redirecting to OAuth provider for connector=#{connector.piece_name} project=#{project.id}"

    redirect_to auth_url, allow_other_host: true
  rescue ActiveRecord::RecordNotFound => e
    redirect_to_error("Record not found: #{e.message}")
  rescue Oauth::ProviderFactory::OauthError => e
    redirect_to_error(e.message)
  end

  # GET /oauth/callback
  # Exchanges authorization code for tokens, creates credential + connection
  def callback
    code = params[:code]
    state_token = params[:state]
    error = params[:error]

    if error.present?
      error_description = params[:error_description] || error
      Rails.logger.warn "[OauthController] OAuth provider returned error: #{error_description}"
      redirect_to_result(success: false, error: error_description)
      return
    end

    unless code.present? && state_token.present?
      redirect_to_result(success: false, error: "Missing authorization code or state")
      return
    end

    state = Oauth::StateManager.consume!(state_token)

    project = Project.find(state[:project_id])
    connector = Connector.find(state[:connector_id])

    provider = Oauth::ProviderFactory.new(connector, project: project)
    redirect_uri = oauth_callback_url

    code_verifier = retrieve_pkce_verifier(state_token)

    tokens = provider.exchange_code(
      code: code,
      redirect_uri: redirect_uri,
      code_verifier: code_verifier
    )

    credential = create_or_update_credential(
      project: project,
      connector: connector,
      tokens: tokens
    )

    connection = find_or_create_connection(
      project: project,
      connector: connector,
      credential: credential
    )

    Rails.logger.info "[OauthController] OAuth flow completed for connector=#{connector.piece_name} project=#{project.id} credential=#{credential.id}"

    redirect_to_result(
      success: true,
      return_to: state[:return_to],
      project_id: project.id,
      connector_name: connector.display_name
    )
  rescue Oauth::StateManager::ExpiredStateError => e
    Rails.logger.warn "[OauthController] State validation failed: #{e.message} (possible duplicate callback)"
    redirect_to_result(success: true, connector_name: "Integration")
  rescue Oauth::ProviderFactory::TokenExchangeError => e
    Rails.logger.error "[OauthController] Token exchange failed: #{e.message}"
    redirect_to_result(success: false, error: "Failed to exchange authorization code: #{e.message}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[OauthController] Record not found during callback: #{e.message}"
    redirect_to_result(success: false, error: "Project or connector not found")
  rescue StandardError => e
    BrainzLab::Reflex.capture(e, context: { controller: "OauthController", action: "callback" })
    Rails.logger.error "[OauthController] Unexpected error in callback: #{e.message}"
    redirect_to_result(success: false, error: "An unexpected error occurred")
  end

  private

  # Authenticate via session (dashboard) or service key (Axon cross-service call)
  def authenticate_request!
    return if session[:user_id].present?

    expected = ENV["SERVICE_KEY"] || "dev_service_key"
    service_key = request.headers["X-Service-Key"].presence || params[:service_key].presence

    if service_key.present? && ActiveSupport::SecurityUtils.secure_compare(service_key, expected)
      return
    end

    render plain: "Unauthorized", status: :unauthorized
  end

  # Never accept user_id from params — use session only
  def current_oauth_user_id
    session[:user_id] || "system"
  end

  def oauth_callback_url
    vault_url = ENV.fetch("VAULT_URL", "http://localhost:#{request.port}")
    "#{vault_url}/oauth/callback"
  end

  def create_or_update_credential(project:, connector:, tokens:)
    credential = project.connector_credentials
                        .where(connector: connector, auth_type: "OAUTH2")
                        .first

    if credential
      credential.store_oauth_tokens!(
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        expires_in: tokens[:expires_in]
      )
      credential
    else
      credential = ConnectorCredential.create_encrypted(
        project: project,
        connector: connector,
        name: "#{connector.display_name} OAuth",
        auth_type: "OAUTH2",
        credentials: { access_token: tokens[:access_token] }
      )

      if tokens[:refresh_token].present?
        credential.store_refresh_token(tokens[:refresh_token])
      end

      if tokens[:expires_in].present?
        credential.update!(token_expires_at: tokens[:expires_in].to_i.seconds.from_now)
      end

      credential
    end
  end

  def find_or_create_connection(project:, connector:, credential:)
    connection = project.connector_connections
                        .where(connector: connector)
                        .first

    if connection
      connection.update!(
        connector_credential: credential,
        status: "connected",
        enabled: true,
        error_message: nil
      )
      connection
    else
      project.connector_connections.create!(
        connector: connector,
        connector_credential: credential,
        name: "#{connector.display_name} Connection",
        status: "connected",
        enabled: true
      )
    end
  end

  def store_pkce_verifier(state_token, code_verifier)
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
    redis.set("vault:oauth:pkce:#{state_token}", code_verifier, ex: 15.minutes.to_i)
  end

  def retrieve_pkce_verifier(state_token)
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
    redis.get("vault:oauth:pkce:#{state_token}")
  end

  def redirect_to_error(message)
    Rails.logger.warn "[OauthController] Error: #{message}"

    if params[:return_to].present?
      uri = safe_redirect_uri(params[:return_to])
      if uri
        redirect_to append_params(uri, error: message), allow_other_host: true
        return
      end
    end

    render plain: "OAuth Error: #{message}", status: :bad_request
  end

  def redirect_to_result(success:, return_to: nil, error: nil, project_id: nil, connector_name: nil)
    if params[:popup] == "true"
      render_popup_response(success: success, error: error, connector_name: connector_name)
      return
    end

    if return_to.present?
      uri = safe_redirect_uri(return_to)
      if uri
        result_params = { oauth: success ? "success" : "error" }
        result_params[:error] = error if error.present?
        result_params[:connector] = connector_name if connector_name.present?
        redirect_to append_params(uri, **result_params), allow_other_host: true
        return
      end
    end

    if success && project_id.present?
      redirect_to "/dashboard/projects/#{project_id}/connector_credentials"
      return
    end

    if success
      render plain: "OAuth authorization successful. You can close this window.", status: :ok
    else
      render plain: "OAuth Error: #{error}", status: :bad_request
    end
  end

  def render_popup_response(success:, error: nil, connector_name: nil)
    message = {
      type: "oauth_callback",
      success: success,
      error: error,
      connector: connector_name
    }.compact.to_json

    opener_origin = ENV.fetch("VAULT_URL", request.base_url)
    safe_status = success ? "Authorization successful." : "Authorization failed."

    render html: <<~HTML.html_safe, layout: false
      <!DOCTYPE html>
      <html>
      <head><title>OAuth Complete</title></head>
      <body>
        <script>
          if (window.opener) {
            window.opener.postMessage(#{message}, #{opener_origin.to_json});
            window.close();
          } else {
            document.body.textContent = #{safe_status.to_json};
          }
        </script>
        <p>#{ERB::Util.html_escape(safe_status)} This window will close automatically.</p>
      </body>
      </html>
    HTML
  end

  def safe_redirect_uri(url)
    return nil if url.blank?

    uri = URI.parse(url)
    return url if uri.relative? && url.start_with?("/")

    host = uri.host
    allowed_hosts = [
      ENV["VAULT_HOST"],
      ENV["BRAINZLAB_PLATFORM_HOST"],
      "localhost",
      "127.0.0.1"
    ].compact

    return url if allowed_hosts.any? { |h| host == h || host&.end_with?(".#{h}") }

    nil
  rescue URI::InvalidURIError
    nil
  end

  def append_params(url, **params)
    uri = URI.parse(url)
    existing = URI.decode_www_form(uri.query || "")
    uri.query = URI.encode_www_form(existing + params.map { |k, v| [k.to_s, v.to_s] })
    uri.to_s
  rescue URI::InvalidURIError
    url
  end
end
