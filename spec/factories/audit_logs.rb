FactoryBot.define do
  factory :audit_log do
    association :project
    action { "read" }
    resource_type { "secret" }
    sequence(:resource_id) { |_n| SecureRandom.uuid }
    resource_path { "/TEST_KEY" }
    actor_type { "system" }
    actor_name { "system" }
    success { true }
  end
end
