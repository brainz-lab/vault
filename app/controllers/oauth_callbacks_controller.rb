# frozen_string_literal: true

class OauthCallbacksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  # GET /oauth/callback/:provider
  def callback
    provider = params[:provider]
    code = params[:code]
    state = params[:state]
    error = params[:error]
    error_description = params[:error_description]

    if error.present?
      return redirect_to_return_url(state, error: error_description || error)
    end

    if code.blank? || state.blank?
      return redirect_to_return_url(state, error: "Missing code or state parameter")
    end

    payload = Connectors::Oauth::StateManager.validate!(state)
    credential = ConnectorCredential.find(payload[:credential_id])

    case provider
    when "salesforce"
      exchange_salesforce_code(credential, code, payload)
    else
      return redirect_to_return_url(state, error: "Unsupported provider: #{provider}")
    end

    redirect_to "#{payload[:return_url]}?oauth=success&credential_id=#{credential.id}", allow_other_host: true
  rescue Connectors::AuthenticationError => e
    redirect_to_return_url(state, error: e.message)
  rescue ActiveRecord::RecordNotFound
    redirect_to_return_url(state, error: "Credential not found")
  rescue StandardError => e
    Rails.logger.error "[OAuthCallback] #{e.class}: #{e.message}"
    redirect_to_return_url(state, error: "OAuth exchange failed: #{e.message}")
  end

  private

  def exchange_salesforce_code(credential, code, payload)
    creds = credential.decrypt_credentials
    instance_url = creds[:instance_url].to_s
    login_url = instance_url.include?("test.salesforce.com") ? "https://test.salesforce.com" : "https://login.salesforce.com"
    callback_url = "#{vault_external_url}/oauth/callback/salesforce"

    token_params = {
      grant_type: "authorization_code",
      code: code,
      client_id: creds[:client_id],
      client_secret: creds[:client_secret],
      redirect_uri: callback_url
    }
    # Include PKCE code_verifier if present
    token_params[:code_verifier] = creds[:_code_verifier] if creds[:_code_verifier].present?

    response = Faraday.post("#{login_url}/services/oauth2/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(token_params)
    end

    unless response.success?
      body = JSON.parse(response.body) rescue {}
      raise Connectors::AuthenticationError, body["error_description"] || body["error"] || "Token exchange failed"
    end

    body = JSON.parse(response.body)
    access_token = body["access_token"]
    refresh_token = body["refresh_token"]
    sf_instance_url = body["instance_url"]

    # Store access_token in encrypted credentials, remove temporary _code_verifier
    new_creds = creds.except(:_code_verifier).merge(
      access_token: access_token,
      instance_url: sf_instance_url || instance_url
    )
    credential.update_credentials(new_creds)

    # Store refresh_token separately
    credential.store_refresh_token(refresh_token) if refresh_token.present?
  end

  def vault_external_url
    ENV.fetch("VAULT_EXTERNAL_URL") { ENV.fetch("VAULT_URL", "http://localhost:4006") }
  end

  def redirect_to_return_url(state, error:)
    return_url = extract_return_url(state)
    if return_url.present?
      redirect_to "#{return_url}?oauth=error&message=#{ERB::Util.url_encode(error)}", allow_other_host: true
    else
      render plain: "OAuth error: #{error}", status: :bad_request
    end
  end

  def extract_return_url(state)
    return nil if state.blank?
    payload = Connectors::Oauth::StateManager.validate!(state)
    payload[:return_url]
  rescue StandardError
    nil
  end
end
