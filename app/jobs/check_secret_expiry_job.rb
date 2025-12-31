class CheckSecretExpiryJob < ApplicationJob
  queue_as :default

  # Run daily to check for secrets that need rotation
  def perform
    rotation_needed = []

    # Check rotation schedules based on rotation_interval_days
    Secret.active.where.not(rotation_interval_days: nil).find_each do |secret|
      last_rotation = secret.versions.maximum(:created_at)
      next unless last_rotation

      days_since_rotation = (Date.current - last_rotation.to_date).to_i
      if days_since_rotation >= secret.rotation_interval_days
        rotation_needed << secret
      end
    end

    # Log findings
    Rails.logger.info "[CheckSecretExpiryJob] #{rotation_needed.count} secrets need rotation"

    # Future: Send notifications
    # Future: Auto-rotate if configured
  end
end
