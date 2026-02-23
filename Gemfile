source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Redis for Action Cable in development
gem "redis", "~> 5.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# AWS SDK for S3-compatible storage (MinIO in development)
gem "aws-sdk-s3", require: false

# ============================================
# Vault-specific dependencies
# ============================================

# HTTP client for Platform integration
gem "faraday", "~> 2.0"

# CORS support
gem "rack-cors"

# BrainzLab SDK
gem "brainzlab", "~> 0.1.12"

# BrainzLab UI - Unified design system with Phlex components
if File.exist?(File.expand_path("../fluyenta-ui", __dir__))
  gem "fluyenta-ui", path: "../fluyenta-ui"
else
  gem "fluyenta-ui", "0.1.3", source: "https://rubygems.pkg.github.com/fluyenta"
end
gem "phlex-rails", "~> 2.0"

# OTP (TOTP/HOTP) generation and verification
gem "rotp", "~> 6.3"

# SSH key management
gem "net-ssh", "~> 7.3"
gem "ed25519", "~> 1.3"
gem "bcrypt_pbkdf", "~> 1.1"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "lefthook", require: false
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Test coverage reporting
  gem "simplecov", require: false
  gem "simplecov-json", require: false

  # Matchers for associations and validations
  gem "shoulda-matchers"

  # DB cleaning between tests
  gem "database_cleaner-active_record"

  # HTTP request mocking
  gem "webmock"

  # Time manipulation for testing
  gem "timecop"

  # Better test output
  gem "minitest-reporters"

  # Pin minitest to compatible version with Rails 8.1
  gem "minitest", "~> 5.25"
end
