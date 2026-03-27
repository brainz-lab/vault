module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def json_headers
    { "Accept" => "application/json" }
  end

  def auth_headers(token_value)
    { "Authorization" => "Bearer #{token_value}" }
  end

  def authenticated_json_headers(token_value)
    json_headers.merge(auth_headers(token_value))
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
