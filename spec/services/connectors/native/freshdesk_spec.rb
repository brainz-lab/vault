# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Freshdesk, type: :service do
  let(:credentials) { { domain: "mycompany", api_key: "fd_test_key" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://mycompany.freshdesk.com/api/v2" }

  it_behaves_like "a native connector"

  describe "#execute list_tickets" do
    it "returns tickets" do
      stub_json_get("#{api_base}/tickets",
        body: [{ id: 1, subject: "Help", status: 2, priority: 1, type: "Question",
          requester_id: 10, responder_id: 20, tags: [], created_at: "2026-01-01", updated_at: "2026-01-02" }])

      result = connector.execute("list_tickets")
      expect(result[:tickets].first[:subject]).to eq("Help")
    end
  end

  describe "#execute create_ticket" do
    it "creates a ticket" do
      stub_json_post("#{api_base}/tickets",
        body: { id: 2, subject: "Issue", status: 2 })

      result = connector.execute("create_ticket", subject: "Issue", description: "Details", email: "user@test.com")
      expect(result[:success]).to be true
    end
  end

  describe "#execute reply_ticket" do
    it "replies to a ticket" do
      stub_json_post("#{api_base}/tickets/1/reply", body: { id: 100 })

      result = connector.execute("reply_ticket", ticket_id: 1, body: "Working on it")
      expect(result[:success]).to be true
    end
  end

  describe "#execute create_contact" do
    it "creates a contact" do
      stub_json_post("#{api_base}/contacts",
        body: { id: 5, name: "New User", email: "new@test.com" })

      result = connector.execute("create_contact", name: "New User", email: "new@test.com")
      expect(result[:success]).to be true
    end
  end
end
