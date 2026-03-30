# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Zendesk, type: :service do
  let(:credentials) { { subdomain: "mycompany", email: "agent@example.com", api_token: "zd_token_123" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://mycompany.zendesk.com/api/v2" }

  it_behaves_like "a native connector"

  describe "#execute list_tickets" do
    it "returns tickets" do
      stub_json_get("#{api_base}/tickets.json",
        body: { tickets: [
          { id: 1, subject: "Help me", description: "I need help", status: "open", priority: "normal",
            type: "question", requester_id: 10, assignee_id: 20, tags: ["vip"], created_at: "2026-01-01", updated_at: "2026-01-02" }
        ] })

      result = connector.execute("list_tickets")
      expect(result[:tickets].first[:subject]).to eq("Help me")
    end
  end

  describe "#execute create_ticket" do
    it "creates a ticket" do
      stub_json_post("#{api_base}/tickets.json",
        body: { ticket: { id: 2, subject: "New issue", status: "new", priority: "high" } })

      result = connector.execute("create_ticket", subject: "New issue", body: "Details", priority: "high")
      expect(result[:success]).to be true
      expect(result[:id]).to eq(2)
    end
  end

  describe "#execute update_ticket" do
    it "updates a ticket" do
      stub_json_put("#{api_base}/tickets/1.json",
        body: { ticket: { id: 1, subject: "Help me", status: "solved" } })

      result = connector.execute("update_ticket", ticket_id: "1", status: "solved")
      expect(result[:success]).to be true
      expect(result[:status]).to eq("solved")
    end
  end

  describe "#execute list_users" do
    it "returns users" do
      stub_json_get("#{api_base}/users.json",
        body: { users: [
          { id: 10, name: "John", email: "john@example.com", role: "agent", active: true, created_at: "2026-01-01" }
        ] })

      result = connector.execute("list_users")
      expect(result[:users].first[:name]).to eq("John")
    end
  end

  describe "#execute search" do
    it "returns search results" do
      stub_json_get("#{api_base}/search.json",
        body: { results: [{ id: 1, result_type: "ticket", subject: "Found it", status: "open", priority: "low" }], count: 1 })

      result = connector.execute("search", query: "status:open", type: "ticket")
      expect(result[:results].first[:subject]).to eq("Found it")
      expect(result[:total]).to eq(1)
    end
  end

  describe "#execute add_comment" do
    it "adds a comment to a ticket" do
      stub_json_put("#{api_base}/tickets/1.json",
        body: { ticket: { id: 1 } })

      result = connector.execute("add_comment", ticket_id: "1", body: "Looking into this")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/tickets.json", body: { error: "Unauthorized" }, status: 401)

      expect { connector.execute("list_tickets") }
        .to raise_error(Connectors::AuthenticationError, /Zendesk/)
    end
  end
end
