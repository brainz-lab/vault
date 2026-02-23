FactoryBot.define do
  factory :project do
    sequence(:platform_project_id) { |n| SecureRandom.uuid }
    sequence(:name) { |n| "Project #{n}" }
    environment { "production" }
  end
end
