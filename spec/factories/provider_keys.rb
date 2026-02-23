FactoryBot.define do
  factory :provider_key do
    association :project
    sequence(:name) { |n| "OpenAI Key #{n}" }
    provider { "openai" }
    model_type { "llm" }
    active { true }
    global { false }
    priority { 0 }
    key_prefix { "sk-test-key-" }

    after(:build) do |pk|
      unless pk.encrypted_key.present?
        # For global keys (project_id nil), use a temp project so KeyManager can create an encryption key
        enc_project_id = pk.project_id.presence || create(:project).id
        enc = Encryption::Encryptor.encrypt("sk-test-key-12345", project_id: enc_project_id)
        pk.encrypted_key      = enc.ciphertext
        pk.encryption_iv      = enc.iv
        pk.encryption_key_id  = enc.key_id
      end
    end

    trait :global do
      global { true }
      project { nil }
    end
  end
end
