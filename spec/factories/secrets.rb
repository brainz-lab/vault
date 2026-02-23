FactoryBot.define do
  factory :secret do
    association :project
    sequence(:key) { |n| "SECRET_KEY_#{n}" }
    secret_type { "string" }
    archived { false }
    versions_count { 0 }

    trait :archived do
      archived { true }
      archived_at { 1.hour.ago }
    end

    trait :credential do
      secret_type { "credential" }
    end

    trait :totp do
      secret_type { "totp" }
    end

    trait :hotp do
      secret_type { "hotp" }
    end
  end
end
