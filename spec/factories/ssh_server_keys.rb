FactoryBot.define do
  factory :ssh_server_key do
    association :project
    sequence(:hostname) { |n| "server-#{n}.example.com" }
    port { 22 }
    key_type { "ssh-ed25519" }
    sequence(:fingerprint) { |_n| "SHA256:#{SecureRandom.hex(20)}" }
    public_key { "ssh-ed25519 AAAA#{SecureRandom.hex(30)}" }
    trusted { true }
    archived { false }

    trait :untrusted do
      trusted { false }
    end

    trait :archived do
      archived { true }
      archived_at { 1.hour.ago }
    end
  end
end
