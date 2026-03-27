require "rails_helper"

RSpec.describe "Api::V1::AuditLogs", type: :request do
  let(:project) { create(:project) }
  let(:token) { create(:access_token, project: project, permissions: %w[read write admin], environments: [ "development" ]) }
  let(:headers) { authenticated_json_headers(token.plain_token) }

  describe "authentication" do
    it "returns unauthorized without a token" do
      get "/api/v1/audit_logs", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates with a valid token" do
      get "/api/v1/audit_logs", headers: headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /api/v1/audit_logs" do
    before do
      create(:audit_log, project: project, action: "read", resource_path: "/SECRET_A", created_at: 2.hours.ago)
      create(:audit_log, project: project, action: "create", resource_path: "/SECRET_B", created_at: 1.hour.ago)
      create(:audit_log, project: project, action: "read", resource_path: "/SECRET_C", created_at: 30.minutes.ago)
    end

    it "returns audit logs with pagination" do
      get "/api/v1/audit_logs", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["logs"].length).to eq(3)
      expect(body["pagination"]).to be_present
      expect(body["pagination"]["total"]).to eq(3)
      expect(body["pagination"]["page"]).to eq(1)
    end

    it "filters by action" do
      get "/api/v1/audit_logs", params: { audit_action: "read" }, headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["logs"].length).to eq(2)
      body["logs"].each do |log|
        expect(log["action"]).to eq("read")
      end
    end

    it "filters by date range" do
      get "/api/v1/audit_logs",
        params: { from: 90.minutes.ago.iso8601, to: 15.minutes.ago.iso8601 },
        headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["logs"].length).to eq(2)
    end

    it "paginates results" do
      get "/api/v1/audit_logs", params: { page: 1, per_page: 2 }, headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["logs"].length).to eq(2)
      expect(body["pagination"]["page"]).to eq(1)
      expect(body["pagination"]["per_page"]).to eq(2)
      expect(body["pagination"]["total"]).to eq(3)
      expect(body["pagination"]["pages"]).to eq(2)
    end

    it "returns logs ordered by most recent first" do
      get "/api/v1/audit_logs", headers: headers

      body = json_response
      timestamps = body["logs"].map { |l| l["created_at"] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end
end
