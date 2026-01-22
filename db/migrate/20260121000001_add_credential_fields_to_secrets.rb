class AddCredentialFieldsToSecrets < ActiveRecord::Migration[8.0]
  def change
    # Add credential-specific fields to secrets
    add_column :secrets, :username, :string

    # OTP configuration fields (stored on the secret, not the version)
    add_column :secrets, :otp_algorithm, :string, default: "sha1"  # sha1, sha256, sha512
    add_column :secrets, :otp_digits, :integer, default: 6
    add_column :secrets, :otp_period, :integer, default: 30        # TOTP interval in seconds
    add_column :secrets, :otp_issuer, :string

    # Index for filtering by secret_type (credential, totp, hotp, etc.)
    add_index :secrets, [ :project_id, :secret_type ]
  end
end
