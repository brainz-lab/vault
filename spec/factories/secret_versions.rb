FactoryBot.define do
  factory :secret_version do
    transient do
      plaintext_value { "test_secret_value" }
    end

    association :secret
    version { 1 }
    current { true }

    before(:create) do |sv, evaluator|
      # Use the project's first default environment
      unless sv.secret_environment_id
        sv.secret_environment = sv.secret.project.secret_environments.first ||
                                create(:secret_environment, project: sv.secret.project)
      end

      # Encrypt the test value
      encrypted = Encryption::Encryptor.encrypt(
        evaluator.plaintext_value,
        project_id: sv.secret.project_id
      )
      sv.encrypted_value = encrypted.ciphertext
      sv.encryption_iv   = encrypted.iv
      sv.encryption_key_id = encrypted.key_id
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
