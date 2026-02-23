FactoryBot.define do
  factory :ssh_connection do
    association :project
    sequence(:name) { |n| "connection-#{n}" }
    host { "example.com" }
    port { 22 }
    username { "deploy" }
    archived { false }

    trait :archived do
      archived { true }
      archived_at { 1.hour.ago }
    end
  end
end
