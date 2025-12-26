class CheckSecretExpiryJob < ApplicationJob
  queue_as :default

  # Run daily to check for secrets that need rotation
  def perform
    upcoming_expirations = []
    rotation_needed = []

    Secret.active.where.not(expires_at: nil).find_each do |secret|
      days_until_expiry = (secret.expires_at.to_date - Date.current).to_i

      if days_until_expiry <= 0
        rotation_needed << secret
      elsif days_until_expiry <= 7
        upcoming_expirations << { secret: secret, days: days_until_expiry }
      end
    end

    # Check rotation schedules
    Secret.active.where.not(rotation_days: nil).find_each do |secret|
      last_rotation = secret.secret_versions.maximum(:created_at)
      next unless last_rotation

      days_since_rotation = (Date.current - last_rotation.to_date).to_i
      if days_since_rotation >= secret.rotation_days
        rotation_needed << secret unless rotation_needed.include?(secret)
      end
    end

    # Log findings
    Rails.logger.info "[CheckSecretExpiryJob] #{upcoming_expirations.count} secrets expiring soon, #{rotation_needed.count} need rotation"

    # Future: Send notifications
    # Future: Auto-rotate if configured
  end
end
