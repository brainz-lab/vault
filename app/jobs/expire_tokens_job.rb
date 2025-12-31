class ExpireTokensJob < ApplicationJob
  queue_as :low

  # Run daily to revoke expired tokens
  def perform
    expired_count = 0

    # Find tokens that are still active but have expired
    # Note: Can't use `active` scope as it filters out expired tokens
    AccessToken.where(active: true, revoked_at: nil)
               .where("expires_at < ?", Time.current).find_each do |token|
      token.revoke!
      expired_count += 1

      AuditLog.log_access(
        project: token.project,
        secret: nil,
        action: "token_expired",
        actor_type: "system",
        actor_id: "expire_tokens_job",
        actor_name: "Token Expiration Job",
        ip_address: nil,
        user_agent: nil,
        details: { token_name: token.name }
      )
    end

    Rails.logger.info "[ExpireTokensJob] Revoked #{expired_count} expired tokens"
  end
end
