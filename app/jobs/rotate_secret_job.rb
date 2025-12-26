class RotateSecretJob < ApplicationJob
  queue_as :default

  def perform(secret_id:, environment_id:, new_value: nil, rotated_by: nil)
    secret = Secret.find(secret_id)
    environment = SecretEnvironment.find(environment_id)

    # Generate new value if not provided
    value = new_value || generate_random_value(secret)

    # Create new version
    secret.set_value(
      environment,
      value,
      user: nil,
      note: "Rotated#{rotated_by ? " by #{rotated_by}" : ""}"
    )

    # Log the rotation
    AuditLog.log_access(
      project: secret.project,
      secret: secret,
      action: "rotate_secret",
      actor_type: "system",
      actor_id: "rotate_job",
      actor_name: "Secret Rotation Job",
      ip_address: nil,
      user_agent: nil,
      details: {
        environment: environment.slug,
        rotated_by: rotated_by,
        new_version: secret.current_version_number
      }
    )

    # Notify callbacks if configured
    notify_rotation(secret, environment)
  end

  private

  def generate_random_value(secret)
    # Generate a random value based on secret type (from tags)
    case secret.tags["type"]
    when "api_key"
      SecureRandom.hex(32)
    when "password"
      SecureRandom.alphanumeric(32)
    when "jwt_secret"
      SecureRandom.base64(64)
    else
      SecureRandom.hex(32)
    end
  end

  def notify_rotation(secret, environment)
    # Future: Send webhook notifications
    # Future: Update dependent services via Synapse
  end
end
