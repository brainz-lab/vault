# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Sendgrid, type: :service do
  let(:credentials) { { api_key: "SG.test_key", from_email: "test@example.com", from_name: "Test Sender" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.sendgrid.com/v3" }

  it_behaves_like "a native connector"

  describe "#execute send_email" do
    it "sends an email and returns success" do
      stub_request(:post, "#{api_base}/mail/send").to_return(status: 202, body: "")

      result = connector.execute("send_email", to: "user@example.com", subject: "Test", body: "Hello")
      expect(result[:success]).to be true
    end

    it "raises error without from_email" do
      connector_no_from = described_class.new({ api_key: "SG.test" })
      stub_request(:post, "#{api_base}/mail/send").to_return(status: 202, body: "")

      expect { connector_no_from.execute("send_email", to: "user@example.com", subject: "Test", body: "Hello") }
        .to raise_error(Connectors::Error, /Sender email/)
    end
  end

  describe "#execute send_template_email" do
    it "sends a template email" do
      stub_request(:post, "#{api_base}/mail/send").to_return(status: 202, body: "")

      result = connector.execute("send_template_email",
        to: "user@example.com", template_id: "d-abc123", dynamic_data: { name: "Alice" }.to_json)
      expect(result[:success]).to be true
    end
  end

  describe "#execute list_contacts" do
    it "returns contacts" do
      stub_json_get("#{api_base}/marketing/contacts",
        body: { result: [ { id: "c1", email: "a@b.com", first_name: "A", last_name: "B", created_at: "2026-01-01" } ] })

      result = connector.execute("list_contacts")
      expect(result[:contacts].first[:email]).to eq("a@b.com")
    end

    it "searches contacts with query" do
      stub_json_post("#{api_base}/marketing/contacts/search",
        body: { result: [ { id: "c2", email: "x@y.com", first_name: "X", last_name: "Y", created_at: "2026-01-01" } ] })

      result = connector.execute("list_contacts", query: "email LIKE '%@y.com'")
      expect(result[:contacts].first[:email]).to eq("x@y.com")
    end
  end

  describe "#execute add_contact" do
    it "adds a contact and returns job_id" do
      stub_json_put("#{api_base}/marketing/contacts", body: { job_id: "job-123" })

      result = connector.execute("add_contact", email: "new@example.com", first_name: "New")
      expect(result[:success]).to be true
      expect(result[:job_id]).to eq("job-123")
    end
  end

  describe "#execute list_lists" do
    it "returns contact lists" do
      stub_json_get("#{api_base}/marketing/lists",
        body: { result: [ { id: "l1", name: "Newsletter", contact_count: 100 } ] })

      result = connector.execute("list_lists")
      expect(result[:lists].first[:name]).to eq("Newsletter")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/marketing/contacts",
        body: { errors: [ { message: "Invalid API key" } ] }, status: 401)

      expect { connector.execute("list_contacts") }
        .to raise_error(Connectors::AuthenticationError, /SendGrid/)
    end
  end
end
