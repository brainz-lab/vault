# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Intercom, type: :service do
  let(:credentials) { { access_token: "ic_test_token" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.intercom.io" }

  it_behaves_like "a native connector"

  describe "#execute list_contacts" do
    it "returns contacts" do
      stub_json_get("#{api_base}/contacts",
        body: { data: [ { id: "c1", external_id: "ext1", email: "a@b.com", name: "Alice",
          phone: "+1234", role: "user", created_at: 1234567890, updated_at: 1234567890 } ], total_count: 1 })

      result = connector.execute("list_contacts")
      expect(result[:contacts].first[:email]).to eq("a@b.com")
      expect(result[:total]).to eq(1)
    end
  end

  describe "#execute search_contacts" do
    it "searches by email" do
      stub_json_post("#{api_base}/contacts/search",
        body: { data: [ { id: "c2", external_id: nil, email: "x@y.com", name: "X",
          phone: nil, role: "lead", created_at: 1, updated_at: 1 } ] })

      result = connector.execute("search_contacts", query: "x@y.com")
      expect(result[:contacts].first[:email]).to eq("x@y.com")
    end
  end

  describe "#execute create_contact" do
    it "creates a contact" do
      stub_json_post("#{api_base}/contacts",
        body: { id: "c3", email: "new@example.com", role: "user" })

      result = connector.execute("create_contact", role: "user", email: "new@example.com")
      expect(result[:success]).to be true
      expect(result[:id]).to eq("c3")
    end
  end

  describe "#execute list_conversations" do
    it "returns conversations" do
      stub_json_get("#{api_base}/conversations",
        body: { conversations: [ { id: "conv1", state: "open", open: true, read: false,
          source: { subject: "Help needed", body: "I need help" }, created_at: 1, updated_at: 1 } ] })

      result = connector.execute("list_conversations")
      expect(result[:conversations].first[:state]).to eq("open")
    end
  end

  describe "#execute reply_conversation" do
    it "replies to a conversation" do
      stub_json_post("#{api_base}/conversations/conv1/reply",
        body: { conversation_id: "conv1" })

      result = connector.execute("reply_conversation", conversation_id: "conv1", body: "On it!", admin_id: "admin1")
      expect(result[:success]).to be true
    end
  end

  describe "#execute send_message" do
    it "sends a message" do
      stub_json_post("#{api_base}/messages",
        body: { message_type: "inapp", id: "msg1" })

      result = connector.execute("send_message", from_admin_id: "admin1", to_contact_id: "c1", body: "Hi!")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/contacts",
        body: { type: "error.list", errors: [ { code: "unauthorized", message: "Invalid token" } ] }, status: 401)

      expect { connector.execute("list_contacts") }
        .to raise_error(Connectors::AuthenticationError, /Intercom/)
    end
  end
end
