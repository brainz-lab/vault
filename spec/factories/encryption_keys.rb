FactoryBot.define do
  factory :encryption_key do
    association :project
    sequence(:key_id) { |_n| SecureRandom.uuid }
    key_type { "aes-256-gcm" }
    status { "active" }
    kms_provider { "local" }

    before(:create) do |ek|
      raw_key  = OpenSSL::Random.random_bytes(32)
      provider = Encryption::LocalKeyProvider.new
      encrypted = provider.encrypt(raw_key)
      ek.encrypted_key   = encrypted[:ciphertext]
      ek.encryption_iv   = encrypted[:iv]
    end

    trait :retired do
      status { "retired" }
      retired_at { 1.hour.ago }
    end

    trait :rotating do
      status { "rotating" }
    end
  end
end
