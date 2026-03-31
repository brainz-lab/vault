# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Trello, type: :service do
  let(:credentials) { { api_key: "trello_key", token: "trello_token" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.trello.com/1" }

  it_behaves_like "a native connector"

  describe "#execute list_boards" do
    it "returns boards" do
      stub_json_get("#{api_base}/members/me/boards",
        body: [{ id: "b1", name: "Project X", closed: false, url: "https://trello.com/b/b1", dateLastActivity: "2026-01-01" }])

      result = connector.execute("list_boards")
      expect(result[:boards].first[:name]).to eq("Project X")
    end
  end

  describe "#execute list_cards" do
    it "returns cards for a list" do
      stub_json_get("#{api_base}/lists/l1/cards",
        body: [{ id: "c1", name: "Task 1", desc: "Do it", due: "2026-04-01", closed: false,
          idList: "l1", labels: [{ name: "urgent" }], shortUrl: "https://trello.com/c/c1" }])

      result = connector.execute("list_cards", list_id: "l1")
      expect(result[:cards].first[:name]).to eq("Task 1")
      expect(result[:cards].first[:labels]).to eq(["urgent"])
    end
  end

  describe "#execute create_card" do
    it "creates a card" do
      stub_json_post("#{api_base}/cards",
        body: { id: "c2", name: "New card", shortUrl: "https://trello.com/c/c2" })

      result = connector.execute("create_card", list_id: "l1", name: "New card")
      expect(result[:success]).to be true
      expect(result[:url]).to eq("https://trello.com/c/c2")
    end
  end

  describe "#execute move_card" do
    it "moves a card to another list" do
      stub_json_put("#{api_base}/cards/c1",
        body: { id: "c1", name: "Task 1", idList: "l2" })

      result = connector.execute("move_card", card_id: "c1", list_id: "l2")
      expect(result[:success]).to be true
    end
  end

  describe "#execute add_comment" do
    it "adds a comment" do
      stub_json_post("#{api_base}/cards/c1/actions/comments", body: { id: "a1" })

      result = connector.execute("add_comment", card_id: "c1", text: "Great progress!")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/members/me/boards", body: { message: "invalid token" }, status: 401)

      expect { connector.execute("list_boards") }
        .to raise_error(Connectors::AuthenticationError, /Trello/)
    end
  end
end
