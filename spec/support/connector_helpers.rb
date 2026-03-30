# frozen_string_literal: true

# Shared helpers and examples for native connector specs.
#
# Usage in specs:
#   RSpec.describe Connectors::Native::MyConnector, type: :service do
#     let(:credentials) { { api_key: "test-key" } }
#     let(:connector) { described_class.new(credentials) }
#
#     it_behaves_like "a native connector"
#   end
#
module ConnectorHelpers
  def stub_json(method, url, body:, status: 200, headers: {})
    stub_request(method, url).to_return(
      status: status,
      body: body.is_a?(String) ? body : body.to_json,
      headers: { "Content-Type" => "application/json" }.merge(headers)
    )
  end

  def stub_json_post(url, body:, status: 200)
    stub_json(:post, url, body: body, status: status)
  end

  def stub_json_get(url, body:, status: 200)
    stub_json(:get, url, body: body, status: status)
  end

  def stub_json_put(url, body:, status: 200)
    stub_json(:put, url, body: body, status: status)
  end
end

RSpec.shared_examples "a native connector" do
  describe ".piece_name" do
    it "returns a non-blank string" do
      expect(described_class.piece_name).to be_present
    end
  end

  describe ".display_name" do
    it "returns a non-blank string" do
      expect(described_class.display_name).to be_present
    end
  end

  describe ".category" do
    it "returns a non-blank string" do
      expect(described_class.category).to be_present
    end
  end

  describe ".auth_type" do
    it "returns a recognized auth type" do
      expect(%w[NONE SECRET_TEXT BASIC OAUTH2 CUSTOM_AUTH]).to include(described_class.auth_type)
    end
  end

  describe ".actions" do
    it "returns a non-empty array of hashes with required keys" do
      actions = described_class.actions
      expect(actions).to be_an(Array)
      expect(actions).not_to be_empty

      actions.each do |action|
        expect(action).to have_key("name")
        expect(action).to have_key("displayName")
        expect(action).to have_key("description")
        expect(action).to have_key("props")
        expect(action["name"]).to match(/\A[a-z_]+\z/)
      end
    end
  end

  describe "#execute with unknown action" do
    it "raises ActionNotFoundError" do
      expect { connector.execute("nonexistent_action_xyz") }
        .to raise_error(Connectors::ActionNotFoundError)
    end
  end
end

RSpec.configure do |config|
  config.include ConnectorHelpers, type: :service
end
