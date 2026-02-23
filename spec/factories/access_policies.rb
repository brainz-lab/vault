FactoryBot.define do
  factory :access_policy do
    association :project
    name { "Test Policy" }
    principal_type { "token" }
    sequence(:principal_id) { |n| SecureRandom.uuid }
    permissions { ["read"] }
    environments { [] }
    paths { [] }
    conditions { {} }
    enabled { true }

    trait :disabled do
      enabled { false }
    end

    trait :full_access do
      permissions { %w[read write delete admin] }
    end
  end
end
