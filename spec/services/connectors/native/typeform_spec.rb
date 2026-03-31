# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Typeform, type: :service do
  let(:credentials) { { access_token: "tf_test_token" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.typeform.com" }

  it_behaves_like "a native connector"

  describe "#execute list_forms" do
    it "returns forms" do
      stub_json_get("#{api_base}/forms",
        body: { items: [ { id: "f1", title: "Survey", status: "public", _links: { responses: "url" }, created_at: "2026-01-01" } ], total_items: 1 })

      result = connector.execute("list_forms")
      expect(result[:forms].first[:title]).to eq("Survey")
      expect(result[:total]).to eq(1)
    end
  end

  describe "#execute get_form" do
    it "returns form with fields" do
      stub_json_get("#{api_base}/forms/f1",
        body: { id: "f1", title: "Survey", status: "public",
          fields: [ { id: "q1", ref: "name_field", title: "Your name?", type: "short_text", validations: { required: true } } ] })

      result = connector.execute("get_form", form_id: "f1")
      expect(result[:fields].first[:title]).to eq("Your name?")
      expect(result[:fields_count]).to eq(1)
    end
  end

  describe "#execute list_responses" do
    it "returns responses" do
      stub_json_get("#{api_base}/forms/f1/responses",
        body: { items: [ { response_id: "r1", landed_at: "2026-01-01", submitted_at: "2026-01-01",
          answers: [ { field: { ref: "name_field", type: "short_text" }, type: "text", text: "Alice" } ] } ], total_items: 1 })

      result = connector.execute("list_responses", form_id: "f1")
      expect(result[:responses].first[:answers].first[:value]).to eq("Alice")
    end
  end

  describe "#execute get_response_count" do
    it "returns total count" do
      stub_json_get("#{api_base}/forms/f1/responses", body: { items: [], total_items: 42 })

      result = connector.execute("get_response_count", form_id: "f1")
      expect(result[:total_responses]).to eq(42)
    end
  end
end
