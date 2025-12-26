source "https://rubygems.org"

# Rails 8
gem "rails", "~> 8.1.1"

# The modern asset pipeline for Rails
gem "propshaft"

# PostgreSQL
gem "pg", "~> 1.1"

# Puma web server
gem "puma", ">= 5.0"

# Hotwire
gem "turbo-rails"
gem "stimulus-rails"

# CSS & JS bundling
gem "jsbundling-rails"
gem "cssbundling-rails"

# JSON APIs
gem "jbuilder"

# Password hashing for API tokens
gem "bcrypt", "~> 3.1.7"

# HTTP client for Platform integration
gem "faraday", "~> 2.0"

# CORS support
gem "rack-cors"

# Timezone data
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Rails 8 adapters
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Redis for ActionCable
gem "redis", "~> 5.0"

# Boot time optimization
gem "bootsnap", require: false

# Deployment
gem "kamal", require: false
gem "thruster", require: false

# BrainzLab SDK - use local path in Docker, published gem otherwise
if File.exist?("/brainzlab-sdk")
  gem "brainzlab", path: "/brainzlab-sdk"
else
  gem "brainzlab", "~> 0.1.1"
end

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
