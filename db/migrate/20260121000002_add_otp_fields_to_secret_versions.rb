class AddOtpFieldsToSecretVersions < ActiveRecord::Migration[8.0]
  def change
    # Encrypted OTP secret (separate from main encrypted_value which holds the password)
    add_column :secret_versions, :encrypted_otp_secret, :binary
    add_column :secret_versions, :otp_secret_iv, :binary
    add_column :secret_versions, :otp_secret_key_id, :string

    # HOTP counter (only used for HOTP type)
    add_column :secret_versions, :hotp_counter, :bigint, default: 0
  end
end
