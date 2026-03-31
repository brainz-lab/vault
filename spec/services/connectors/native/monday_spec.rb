# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Monday, type: :service do
  let(:credentials) { { api_token: "monday_test_token" } }
  let(:connector) { described_class.new(credentials) }

  it_behaves_like "a native connector"

  describe "#execute list_boards" do
    it "returns boards via GraphQL" do
      stub_json_post("https://api.monday.com/v2",
        body: { data: { boards: [ { id: "1", name: "Sprint Board", state: "active", board_kind: "public",
          columns: [ { id: "status", title: "Status", type: "color" } ] } ] } })

      result = connector.execute("list_boards")
      expect(result[:boards].first[:name]).to eq("Sprint Board")
    end
  end

  describe "#execute create_item" do
    it "creates an item" do
      stub_json_post("https://api.monday.com/v2",
        body: { data: { create_item: { id: "123", name: "New task" } } })

      result = connector.execute("create_item", board_id: "1", item_name: "New task")
      expect(result[:success]).to be true
      expect(result[:id]).to eq("123")
    end
  end

  describe "#execute add_update" do
    it "adds an update" do
      stub_json_post("https://api.monday.com/v2",
        body: { data: { create_update: { id: "u1" } } })

      result = connector.execute("add_update", item_id: "123", body: "Progress report")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises on GraphQL errors" do
      stub_json_post("https://api.monday.com/v2",
        body: { errors: [ { message: "Not Authenticated" } ] })

      expect { connector.execute("list_boards") }
        .to raise_error(Connectors::AuthenticationError, /Monday/)
    end
  end
end
