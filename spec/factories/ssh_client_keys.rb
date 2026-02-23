FactoryBot.define do
  factory :ssh_client_key do
    association :project
    sequence(:name) { |n| "key-#{n}" }
    key_type { "ed25519" }
    sequence(:fingerprint) { |_n| "SHA256:#{SecureRandom.hex(20)}" }
    public_key { "ssh-ed25519 AAAA#{SecureRandom.hex(30)} test@example.com" }
    archived { false }

    before(:create) do |k|
      plaintext = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest_private_key_data\n-----END OPENSSH PRIVATE KEY-----"
      enc = Encryption::Encryptor.encrypt(plaintext, project_id: k.project_id)
      k.encrypted_private_key  = enc.ciphertext
      k.private_key_iv         = enc.iv
      k.private_key_key_id     = enc.key_id
    end

    trait :with_passphrase do
      before(:create) do |k|
        enc = Encryption::Encryptor.encrypt("my_passphrase", project_id: k.project_id)
        k.encrypted_passphrase = enc.ciphertext
        k.passphrase_iv        = enc.iv
        k.passphrase_key_id    = enc.key_id
      end
    end

    trait :archived do
      archived { true }
      archived_at { 1.hour.ago }
    end
  end
end
