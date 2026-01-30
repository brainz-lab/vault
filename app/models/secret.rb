class Secret < ApplicationRecord
  # Secret types supported by Vault
  SECRET_TYPES = %w[string json file certificate credential totp hotp].freeze
  OTP_TYPES = %w[credential totp hotp].freeze
  OTP_ALGORITHMS = %w[sha1 sha256 sha512].freeze

  belongs_to :project
  belongs_to :secret_folder, optional: true

  has_many :versions, class_name: "SecretVersion", dependent: :destroy

  validates :key, presence: true, format: {
    with: /\A[A-Z][A-Z0-9_]*\z/,
    message: "must be uppercase with underscores (e.g., DATABASE_URL)"
  }
  validates :path, presence: true, uniqueness: { scope: :project_id }
  validates :secret_type, inclusion: { in: SECRET_TYPES }
  validates :otp_algorithm, inclusion: { in: OTP_ALGORITHMS }, allow_nil: true
  validates :otp_digits, inclusion: { in: 6..8 }, allow_nil: true
  validates :otp_period, numericality: { greater_than: 0, less_than_or_equal_to: 120 }, allow_nil: true

  before_validation :set_path
  before_validation :normalize_key

  # Convert a URL or domain to a valid secret key
  # Examples:
  #   "https://hey.com" => "HEY_COM"
  #   "app.github.com" => "APP_GITHUB_COM"
  #   "my-service" => "MY_SERVICE"
  def self.normalize_key(input)
    return input if input.blank?

    # If already valid uppercase key, return as-is
    return input if input.match?(/\A[A-Z][A-Z0-9_]*\z/)

    # Extract domain from URL if present
    key = input.to_s.dup

    # Remove protocol
    key.gsub!(%r{^https?://}, "")
    # Remove path, query, fragment
    key.gsub!(%r{[/?#].*$}, "")
    # Remove port
    key.gsub!(/:[\d]+$/, "")
    # Remove www. prefix
    key.gsub!(/^www\./, "")

    # Replace dots and hyphens with underscores
    key.gsub!(/[.\-]/, "_")
    # Remove any other non-alphanumeric characters
    key.gsub!(/[^A-Za-z0-9_]/, "")
    # Convert to uppercase
    key.upcase!
    # Ensure starts with letter
    key = "X#{key}" unless key.match?(/\A[A-Z]/)
    # Collapse multiple underscores
    key.gsub!(/_+/, "_")
    # Remove trailing underscore
    key.gsub!(/_+$/, "")

    key
  end

  scope :active, -> { where(archived: false) }
  scope :in_folder, ->(folder) { where(secret_folder: folder) }
  scope :with_tag, ->(key, value) { where("tags->>? = ?", key, value) }
  scope :credentials, -> { where(secret_type: %w[credential totp hotp]) }

  # Checks if this secret supports OTP
  def otp_enabled?
    OTP_TYPES.include?(secret_type)
  end

  # Checks if this secret is a credential type (has username/password)
  def credential?
    secret_type == "credential"
  end

  # Use counter cache to avoid N+1 queries
  def has_versions?
    versions_count > 0
  end

  def current_version(environment)
    # Use preloaded versions if available (avoids N+1), otherwise query
    if versions.loaded?
      versions.find { |v| v.secret_environment_id == environment.id && v.current }
    else
      versions.where(secret_environment: environment, current: true).first
    end
  end

  # Returns the current version number for a given environment
  # If no environment is passed, returns the highest version number across all environments
  def current_version_number(environment = nil)
    if environment
      current_version(environment)&.version
    else
      # Use preloaded versions if available (avoids N+1), otherwise query
      if versions.loaded?
        versions.select(&:current).map(&:version).max
      else
        versions.where(current: true).maximum(:version)
      end
    end
  end

  def value(environment)
    version = current_version(environment)
    return nil unless version

    version.decrypt
  end

  def set_value(environment, value, user: nil, note: nil)
    ActiveRecord::Base.transaction do
      # Mark previous version as not current
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)

      # Create new version
      version_number = versions.where(secret_environment: environment).maximum(:version).to_i + 1

      encrypted_data = Encryption::Encryptor.encrypt(value, project_id: project_id)

      versions.create!(
        secret_environment: environment,
        version: version_number,
        current: true,
        encrypted_value: encrypted_data.ciphertext,
        encryption_iv: encrypted_data.iv,
        encryption_key_id: encrypted_data.key_id,
        value_length: value.length,
        value_hash: Digest::SHA256.hexdigest(value),
        created_by: user,
        change_note: note
      )
    end
  end

  def version_history(environment, limit: 10)
    versions.where(secret_environment: environment)
            .order(version: :desc)
            .limit(limit)
  end

  def rollback(environment, to_version:, user: nil)
    target = versions.find_by!(secret_environment: environment, version: to_version)

    ActiveRecord::Base.transaction do
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)

      new_version = versions.create!(
        secret_environment: environment,
        version: versions.where(secret_environment: environment).maximum(:version) + 1,
        current: true,
        encrypted_value: target.encrypted_value,
        encryption_iv: target.encryption_iv,
        encryption_key_id: target.encryption_key_id,
        value_length: target.value_length,
        value_hash: target.value_hash,
        created_by: user,
        change_note: "Rollback to version #{to_version}"
      )

      new_version
    end
  end

  def archive!(user: nil)
    update!(archived: true, archived_at: Time.current)

    AuditLog.create!(
      project: project,
      action: "archive",
      resource_type: "secret",
      resource_id: id,
      resource_path: path,
      actor_type: user ? "user" : "system",
      actor_id: user,
      actor_name: user || "system"
    )
  end

  # Set credential with username and password (without OTP)
  def set_credential(environment, username:, password:, user: nil, note: nil)
    update!(secret_type: "credential", username: username) unless credential?

    set_value(environment, password, user: user, note: note)
  end

  # Set credential with username, password, and OTP secret
  def set_credential_with_otp(environment, username:, password:, otp_secret:, otp_type: "totp", otp_algorithm: "sha1", otp_digits: 6, otp_period: 30, otp_issuer: nil, user: nil, note: nil)
    # Update secret metadata for OTP
    update!(
      secret_type: otp_type == "hotp" ? "hotp" : "credential",
      username: username,
      otp_algorithm: otp_algorithm,
      otp_digits: otp_digits,
      otp_period: otp_period,
      otp_issuer: otp_issuer
    )

    ActiveRecord::Base.transaction do
      # Mark previous version as not current
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)

      # Create new version
      version_number = versions.where(secret_environment: environment).maximum(:version).to_i + 1

      # Encrypt password
      encrypted_password = Encryption::Encryptor.encrypt(password, project_id: project_id)

      # Encrypt OTP secret
      encrypted_otp = Encryption::Encryptor.encrypt(otp_secret, project_id: project_id)

      versions.create!(
        secret_environment: environment,
        version: version_number,
        current: true,
        encrypted_value: encrypted_password.ciphertext,
        encryption_iv: encrypted_password.iv,
        encryption_key_id: encrypted_password.key_id,
        value_length: password.length,
        value_hash: Digest::SHA256.hexdigest(password),
        encrypted_otp_secret: encrypted_otp.ciphertext,
        otp_secret_iv: encrypted_otp.iv,
        otp_secret_key_id: encrypted_otp.key_id,
        created_by: user,
        change_note: note
      )
    end
  end

  # Get full credential including OTP code if available
  def get_credential(environment, include_otp: false)
    version = current_version(environment)
    return nil unless version

    result = {
      username: username,
      password: version.decrypt
    }

    if include_otp && otp_enabled? && version.has_otp_secret?
      result[:otp] = generate_otp(environment)
    end

    result
  end

  # Generate OTP code for TOTP/HOTP secrets
  def generate_otp(environment)
    raise ArgumentError, "Secret does not support OTP" unless otp_enabled?

    version = current_version(environment)
    raise ArgumentError, "No OTP secret configured" unless version&.has_otp_secret?

    otp_secret = version.decrypt_otp_secret

    if secret_type == "hotp"
      # HOTP - counter-based
      Otp::Generator.generate_hotp(
        otp_secret,
        counter: version.hotp_counter,
        digits: otp_digits || 6,
        algorithm: otp_algorithm || "sha1"
      )
    else
      # TOTP - time-based (default for credential type)
      Otp::Generator.generate_totp(
        otp_secret,
        digits: otp_digits || 6,
        period: otp_period || 30,
        algorithm: otp_algorithm || "sha1"
      )
    end
  end

  # Verify an OTP code
  def verify_otp(environment, code)
    raise ArgumentError, "Secret does not support OTP" unless otp_enabled?

    version = current_version(environment)
    raise ArgumentError, "No OTP secret configured" unless version&.has_otp_secret?

    otp_secret = version.decrypt_otp_secret

    if secret_type == "hotp"
      result = Otp::Verifier.verify_hotp(
        otp_secret,
        code,
        counter: version.hotp_counter,
        digits: otp_digits || 6,
        algorithm: otp_algorithm || "sha1"
      )

      # Update counter if valid
      if result[:valid]
        version.update!(hotp_counter: result[:new_counter])
      end

      result
    else
      Otp::Verifier.verify_totp(
        otp_secret,
        code,
        digits: otp_digits || 6,
        period: otp_period || 30,
        algorithm: otp_algorithm || "sha1"
      )
    end
  end

  # Increment HOTP counter after use (for HOTP only)
  def increment_hotp_counter!(environment)
    return unless secret_type == "hotp"

    version = current_version(environment)
    version&.increment!(:hotp_counter)
  end

  private

  def set_path
    folder_path = secret_folder&.path || ""
    self.path = "#{folder_path}/#{key}".gsub(/^\/+/, "/")
  end

  def normalize_key
    # Only auto-normalize if key doesn't match the required format
    # This allows users to set explicit keys but also accepts URLs/domains
    return if key.blank?
    return if key.match?(/\A[A-Z][A-Z0-9_]*\z/)

    self.key = self.class.normalize_key(key)
  end
end
