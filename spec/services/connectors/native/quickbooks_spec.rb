# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Quickbooks, type: :service do
  let(:credentials) { { access_token: "qb_test_token", realm_id: "123456789", environment: "production" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://quickbooks.api.intuit.com/v3/company/123456789" }

  it_behaves_like "a native connector"

  describe "#execute list_invoices" do
    it "returns invoices" do
      stub_json_get("#{api_base}/query",
        body: { QueryResponse: { Invoice: [
          { Id: "1", DocNumber: "1001", CustomerRef: { name: "Acme" }, TotalAmt: 500.0,
            Balance: 0.0, DueDate: "2026-02-01", MetaData: { CreateTime: "2026-01-01" } }
        ] } })

      result = connector.execute("list_invoices")
      expect(result[:invoices].first[:doc_number]).to eq("1001")
      expect(result[:invoices].first[:status]).to eq("paid")
    end
  end

  describe "#execute create_invoice" do
    it "creates an invoice" do
      stub_json_post("#{api_base}/invoice",
        body: { Invoice: { Id: "2", DocNumber: "1002", TotalAmt: 250.0 } })

      result = connector.execute("create_invoice",
        customer_id: "cust1",
        line_items: [{ description: "Consulting", amount: 250, quantity: 1 }].to_json)
      expect(result[:success]).to be true
      expect(result[:total]).to eq(250.0)
    end
  end

  describe "#execute list_customers" do
    it "returns customers" do
      stub_json_get("#{api_base}/query",
        body: { QueryResponse: { Customer: [
          { Id: "c1", DisplayName: "Acme Corp", CompanyName: "Acme",
            PrimaryEmailAddr: { Address: "billing@acme.com" }, PrimaryPhone: { FreeFormNumber: "+1234" },
            Balance: 1000.0, Active: true }
        ] } })

      result = connector.execute("list_customers")
      expect(result[:customers].first[:display_name]).to eq("Acme Corp")
    end
  end

  describe "#execute create_customer" do
    it "creates a customer" do
      stub_json_post("#{api_base}/customer",
        body: { Customer: { Id: "c2", DisplayName: "New Corp" } })

      result = connector.execute("create_customer", display_name: "New Corp", email: "new@corp.com")
      expect(result[:success]).to be true
    end
  end

  describe "sandbox environment" do
    it "uses sandbox URL" do
      sandbox = described_class.new({ access_token: "tok", realm_id: "999", environment: "sandbox" })
      stub_json_get("https://sandbox-quickbooks.api.intuit.com/v3/company/999/query",
        body: { QueryResponse: { CompanyInfo: [{ CompanyName: "Sandbox Co" }] } })

      result = sandbox.execute("get_company_info")
      expect(result[:name]).to eq("Sandbox Co")
    end
  end
end
