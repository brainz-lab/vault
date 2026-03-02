require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
ENV["BRAINZLAB_SDK_ENABLED"] = "false"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "factory_bot_rails"
require "database_cleaner/active_record"
require "webmock/rspec"
require "timecop"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

WebMock.disable_net_connect!(allow_localhost: true)

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Stub PlatformClient for tests
class PlatformClient
  def self.validate_key(api_key)
    if api_key == "valid_key"
      {
        valid: true,
        project_id: "prj_test123",
        project_name: "Test Project",
        environment: "live",
        features: { vault: true }
      }
    elsif api_key&.start_with?("vlt_")
      nil
    else
      { valid: false }
    end
  end

  def self.track_usage(project_id:, product:, metric:, count:)
    true
  end

  def self.get_project_config(platform_project_id:)
    {
      name: "Test Project",
      environment: "live"
    }
  end
end
