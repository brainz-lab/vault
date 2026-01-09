require_relative "boot"

require "rails/all"

# Patch for phlex-rails 2.3.1 compatibility with Rails 8.1+
# Pre-define Phlex::Rails::Streaming with ActiveSupport::Concern BEFORE phlex-rails loads
# See: https://github.com/phlex-ruby/phlex-rails/issues/323
module Phlex
  module Rails
    module Streaming
      extend ActiveSupport::Concern
      include ActionController::Live
    end
  end
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Vault
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use SQL schema format for better compatibility
    config.active_record.schema_format = :sql
  end
end
