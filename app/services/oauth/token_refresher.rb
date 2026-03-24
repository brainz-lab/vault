module Oauth
  class TokenRefresher
    class RefreshFailedError < StandardError; end

    attr_reader :credential

    def initialize(credential)
      @credential = credential
    end

    def refresh!
      unless credential.auth_type == "OAUTH2"
        raise RefreshFailedError, "Credential '#{credential.name}' is not an OAuth2 credential"
      end

      refresh_token = credential.decrypt_refresh_token
      unless refresh_token.present?
        credential.mark_error!("No refresh token available")
        raise RefreshFailedError, "No refresh token available for credential '#{credential.name}'"
      end

      connector = credential.connector
      provider = Oauth::ProviderFactory.new(connector)

      tokens = provider.refresh_tokens(refresh_token)

      credential.store_oauth_tokens!(
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        expires_in: tokens[:expires_in]
      )

      Rails.logger.info "[Oauth::TokenRefresher] Refreshed tokens for credential=#{credential.id} (#{credential.name})"

      tokens
    rescue Oauth::ProviderFactory::RefreshError => e
      credential.mark_error!("Token refresh failed: #{e.message}")
      raise RefreshFailedError, "Failed to refresh credential '#{credential.name}': #{e.message}"
    end
  end
end
