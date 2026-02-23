FactoryBot.define do
  factory :access_token do
    association :project
    name { "Test Token" }
    active { true }
    permissions { ["read"] }
    environments { [] }
    paths { [] }

    trait :revoked do
      active { false }
      revoked_at { 1.hour.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :full_access do
      permissions { %w[read write delete admin] }
    end
  end
end
