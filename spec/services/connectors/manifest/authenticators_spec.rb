require "rails_helper"
require "ostruct"

RSpec.describe "Connectors::Manifest::Authenticators" do
  let(:interpolator) { Connectors::Manifest::Interpolator.new(config: { "token" => "my-secret", "user" => "admin", "pass" => "s3cret" }) }

  describe Connectors::Manifest::Authenticators::Bearer do
    it "sets Authorization Bearer header" do
      auth = described_class.new(
        { "api_token" => "{{ config['token'] }}" },
        { "token" => "my-secret" },
        interpolator: interpolator
      )
      req = OpenStruct.new(headers: {})
      auth.apply(req)
      expect(req.headers["Authorization"]).to eq("Bearer my-secret")
    end

    it "raises when token is blank" do
      empty_interp = Connectors::Manifest::Interpolator.new(config: {})
      auth = described_class.new({ "api_token" => "{{ config['token'] }}" }, {}, interpolator: empty_interp)
      req = OpenStruct.new(headers: {})
      expect { auth.apply(req) }.to raise_error(Connectors::AuthenticationError, /blank/)
    end
  end

  describe Connectors::Manifest::Authenticators::ApiKey do
    it "injects into header" do
      auth = described_class.new(
        { "api_token" => "{{ config['token'] }}", "inject_into" => { "field_name" => "X-Api-Key", "inject_into" => "header" } },
        { "token" => "my-secret" },
        interpolator: interpolator
      )
      req = OpenStruct.new(headers: {}, params: {})
      auth.apply(req)
      expect(req.headers["X-Api-Key"]).to eq("my-secret")
    end

    it "injects into request_parameter" do
      auth = described_class.new(
        { "api_token" => "{{ config['token'] }}", "inject_into" => { "field_name" => "api_key", "inject_into" => "request_parameter" } },
        { "token" => "my-secret" },
        interpolator: interpolator
      )
      req = OpenStruct.new(headers: {}, params: {})
      auth.apply(req)
      expect(req.params["api_key"]).to eq("my-secret")
    end
  end

  describe Connectors::Manifest::Authenticators::BasicHttp do
    it "sets Basic auth header" do
      auth = described_class.new(
        { "username" => "{{ config['user'] }}", "password" => "{{ config['pass'] }}" },
        { "user" => "admin", "pass" => "s3cret" },
        interpolator: interpolator
      )
      req = OpenStruct.new(headers: {})
      auth.apply(req)
      expected = "Basic #{Base64.strict_encode64('admin:s3cret')}"
      expect(req.headers["Authorization"]).to eq(expected)
    end
  end

  describe Connectors::Manifest::Authenticators::Oauth do
    it "uses access_token from credentials" do
      auth = described_class.new({}, { access_token: "oauth-token-123" }, interpolator: interpolator)
      req = OpenStruct.new(headers: {})
      auth.apply(req)
      expect(req.headers["Authorization"]).to eq("Bearer oauth-token-123")
    end

    it "raises when access_token missing" do
      auth = described_class.new({}, {}, interpolator: interpolator)
      req = OpenStruct.new(headers: {})
      expect { auth.apply(req) }.to raise_error(Connectors::AuthenticationError, /access_token/)
    end
  end

  describe Connectors::Manifest::Authenticators::NoAuth do
    it "does nothing" do
      auth = described_class.new({}, {}, interpolator: interpolator)
      req = OpenStruct.new(headers: {})
      auth.apply(req)
      expect(req.headers).to be_empty
    end
  end
end
