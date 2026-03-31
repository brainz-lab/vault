# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Pipedrive, type: :service do
  let(:credentials) { { api_token: "pd_test_token", company_domain: "mycompany" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://mycompany.pipedrive.com/api/v1" }

  it_behaves_like "a native connector"

  describe "#execute list_deals" do
    it "returns deals" do
      stub_json_get("#{api_base}/deals",
        body: { success: true, data: [
          { id: 1, title: "Big deal", value: 10000, currency: "USD", status: "open", stage_id: 1,
            person_id: { name: "Alice" }, org_id: { name: "Acme" }, add_time: "2026-01-01" }
        ] })

      result = connector.execute("list_deals")
      expect(result[:deals].first[:title]).to eq("Big deal")
    end
  end

  describe "#execute create_deal" do
    it "creates a deal" do
      stub_json_post("#{api_base}/deals",
        body: { success: true, data: { id: 2, title: "New deal" } })

      result = connector.execute("create_deal", title: "New deal", value: 5000)
      expect(result[:success]).to be true
      expect(result[:id]).to eq(2)
    end
  end

  describe "#execute list_persons" do
    it "returns persons" do
      stub_json_get("#{api_base}/persons",
        body: { success: true, data: [
          { id: 10, name: "Bob", email: [ { value: "bob@example.com" } ], phone: [ { value: "+1234" } ], org_id: { name: "Corp" } }
        ] })

      result = connector.execute("list_persons")
      expect(result[:persons].first[:name]).to eq("Bob")
    end
  end

  describe "#execute create_activity" do
    it "creates an activity" do
      stub_json_post("#{api_base}/activities",
        body: { success: true, data: { id: 5, subject: "Follow up", type: "call" } })

      result = connector.execute("create_activity", subject: "Follow up", type: "call")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/deals",
        body: { success: false, error: "Unauthorized" }, status: 401)

      expect { connector.execute("list_deals") }
        .to raise_error(Connectors::AuthenticationError)
    end
  end
end
