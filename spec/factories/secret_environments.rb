FactoryBot.define do
  factory :secret_environment do
    association :project
    sequence(:name) { |n| "Environment #{n}" }
    sequence(:slug) { |n| "environment-#{n}" }
    position { 10 }
    color { "#6b7280" }
  end
end
