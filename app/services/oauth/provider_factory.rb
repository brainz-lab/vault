module Oauth
  class ProviderFactory
    class OauthError < StandardError; end
    class TokenExchangeError < OauthError; end
    class RefreshError < OauthError; end

    CALLBACK_PATH = "/oauth/callback"

    attr_reader :connector, :project

    # project is optional — when provided, checks for a Vault secret
    # named "OAUTH_{CONNECTOR_KEY}" in the project as enterprise override.
    #
    # credentials is optional — when provided, uses these client_id/client_secret
    # instead of looking in ENV or Vault secrets. Used for connectors where each
    # customer provides their own OAuth app (e.g. Salesforce).
    def initialize(connector, project: nil, credentials: nil)
      @connector = connector
      @project = project
      @explicit_credentials = credentials
    end

    def authorization_url(state:, redirect_uri:, code_challenge: nil, code_challenge_method: nil)
      auth = auth_config

      params = {
        response_type: "code",
        client_id: oauth_client_id,
        redirect_uri: redirect_uri,
        state: state,
        scope: auth[:scope]
      }.compact

      if pkce_enabled?
        params[:code_challenge] = code_challenge
        params[:code_challenge_method] = code_challenge_method || "S256"
      end

      uri = URI.parse(auth[:authUrl])
      existing_params = URI.decode_www_form(uri.query || "")
      uri.query = URI.encode_www_form(existing_params + params.to_a)

      uri.to_s
    end

    def exchange_code(code:, redirect_uri:, code_verifier: nil)
      auth = auth_config

      body = {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: oauth_client_id,
        client_secret: oauth_client_secret
      }

      body[:code_verifier] = code_verifier if pkce_enabled? && code_verifier.present?

      response = token_request(auth[:tokenUrl], body)

      parse_token_response(response)
    rescue Faraday::Error => e
      raise TokenExchangeError, "Token exchange failed: #{e.message}"
    end

    def refresh_tokens(refresh_token)
      auth = auth_config

      body = {
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: oauth_client_id,
        client_secret: oauth_client_secret
      }

      response = token_request(auth[:tokenUrl], body)

      parse_token_response(response)
    rescue Faraday::Error => e
      raise RefreshError, "Token refresh failed: #{e.message}"
    end

    # Lookup order:
    # 1. Explicit credentials (user-provided, e.g. Salesforce per-customer Connected App)
    # 2. Vault secret "OAUTH_{CONNECTOR}" in project (enterprise override)
    # 3. ENV variable VAULT_OAUTH_{CONNECTOR}_CLIENT_ID (platform default)
    def oauth_client_id
      return @explicit_credentials[:client_id] if @explicit_credentials&.dig(:client_id).present?

      vault_creds = vault_oauth_credentials
      return vault_creds[:client_id] if vault_creds

      env_key = "VAULT_OAUTH_#{connector_env_key}_CLIENT_ID"
      ENV.fetch(env_key) { raise OauthError, "Missing #{env_key}. Set it in ENV or create a Vault secret 'OAUTH_#{connector_env_key}' (type: credential) in the project." }
    end

    def oauth_client_secret
      return @explicit_credentials[:client_secret] if @explicit_credentials&.dig(:client_secret).present?

      vault_creds = vault_oauth_credentials
      return vault_creds[:client_secret] if vault_creds

      env_key = "VAULT_OAUTH_#{connector_env_key}_CLIENT_SECRET"
      ENV.fetch(env_key) { raise OauthError, "Missing #{env_key}" }
    end

    # True if this project uses its own OAuth app via Vault secrets
    def using_custom_app?
      vault_oauth_credentials.present?
    end

    def pkce_enabled?
      auth_config[:pkce] == true
    end

    def generate_pkce
      code_verifier = SecureRandom.urlsafe_base64(32)
      code_challenge = Base64.urlsafe_encode64(
        Digest::SHA256.digest(code_verifier),
        padding: false
      )

      { code_verifier: code_verifier, code_challenge: code_challenge, code_challenge_method: "S256" }
    end

    private

    def auth_config
      schema = connector.auth_schema || {}

      {
        authUrl: schema["authUrl"] || schema[:authUrl],
        tokenUrl: schema["tokenUrl"] || schema[:tokenUrl],
        scope: schema["scope"] || schema[:scope],
        pkce: schema["pkce"] || schema[:pkce]
      }.tap do |config|
        raise OauthError, "Connector '#{connector.piece_name}' missing authUrl in auth_schema" unless config[:authUrl].present?
        raise OauthError, "Connector '#{connector.piece_name}' missing tokenUrl in auth_schema" unless config[:tokenUrl].present?
      end
    end

    def connector_env_key
      connector.piece_name.upcase.gsub(/[^A-Z0-9]/, "_")
    end

    # Enterprise override: look for a Vault secret named "OAUTH_{CONNECTOR_KEY}"
    # of type "credential" in the project. Uses username as client_id, password as client_secret.
    # Results are memoized per instance to avoid repeated DB/decryption calls.
    def vault_oauth_credentials
      return @vault_creds if defined?(@vault_creds)

      @vault_creds = begin
        return nil unless project

        secret = project.secrets.find_by(key: "OAUTH_#{connector_env_key}", secret_type: "credential")
        return nil unless secret

        cred_value = secret.value("production") || secret.value("development")
        return nil unless cred_value.is_a?(Hash) && cred_value["username"].present?

        { client_id: cred_value["username"], client_secret: cred_value["password"] }
      end
    end

    def token_request(url, body)
      connection = Faraday.new do |f|
        f.request :url_encoded
        f.response :json
        f.options.timeout = 15
        f.options.open_timeout = 5
      end

      connection.post(url, body)
    end

    def parse_token_response(response)
      unless response.success?
        error_detail = response.body.is_a?(Hash) ? (response.body["error_description"] || response.body["error"]) : response.body.to_s
        raise TokenExchangeError, "Token endpoint returned HTTP #{response.status}: #{error_detail}"
      end

      body = response.body

      {
        access_token: body["access_token"],
        refresh_token: body["refresh_token"],
        expires_in: body["expires_in"],
        token_type: body["token_type"],
        scope: body["scope"],
        instance_url: body["instance_url"]
      }.compact.tap do |tokens|
        raise TokenExchangeError, "Token response missing access_token" unless tokens[:access_token].present?
      end
    end
  end
end
