class OauthTokenRefreshJob < ApplicationJob
  queue_as :default

  # Runs every 5 minutes to proactively refresh OAuth2 tokens nearing expiration
  def perform
    refreshed_count = 0
    failed_count = 0

    credentials_needing_refresh.find_each do |credential|
      refresh_credential(credential)
      refreshed_count += 1
    rescue Oauth::TokenRefresher::RefreshFailedError, Oauth::ProviderFactory::RefreshError => e
      failed_count += 1
      Rails.logger.warn "[OauthTokenRefreshJob] Failed to refresh credential=#{credential.id} (#{credential.name}): #{e.message}"
    end

    Rails.logger.info "[OauthTokenRefreshJob] Refreshed #{refreshed_count} credentials, #{failed_count} failures"
  end

  private

  def credentials_needing_refresh
    ConnectorCredential
      .where(auth_type: "OAUTH2", status: "active")
      .where("token_expires_at IS NOT NULL AND token_expires_at < ?", 10.minutes.from_now)
      .where("encrypted_refresh_token IS NOT NULL")
      .includes(:connector)
  end

  def refresh_credential(credential)
    refresher = Oauth::TokenRefresher.new(credential)
    refresher.refresh!
  end
end
