# frozen_string_literal: true

Anthropic.configure do |config|
  key = ENV["ANTHROPIC_API_KEY"]
  key = key.gsub(/:-\}$/, "") if key.present?
  config.access_token = key if key.present?
end
