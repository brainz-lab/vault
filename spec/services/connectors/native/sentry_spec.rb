# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Sentry, type: :service do
  let(:credentials) { { auth_token: "sentry_test_token", organization_slug: "myorg" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://sentry.io/api/0" }

  it_behaves_like "a native connector"

  describe "#execute list_issues" do
    it "returns issues" do
      stub_json_get("#{api_base}/projects/myorg/web-app/issues/",
        body: [{ id: "1", title: "TypeError: undefined", culprit: "app.js", status: "unresolved",
          level: "error", count: 42, userCount: 10, firstSeen: "2026-01-01", lastSeen: "2026-01-02",
          assignedTo: nil, permalink: "https://sentry.io/issues/1/" }])

      result = connector.execute("list_issues", project_slug: "web-app")
      expect(result[:issues].first[:title]).to eq("TypeError: undefined")
      expect(result[:issues].first[:count]).to eq(42)
    end
  end

  describe "#execute resolve_issue" do
    it "resolves an issue" do
      stub_json_put("#{api_base}/issues/1/",
        body: { id: "1", status: "resolved" })

      result = connector.execute("resolve_issue", issue_id: "1")
      expect(result[:success]).to be true
      expect(result[:status]).to eq("resolved")
    end
  end

  describe "#execute list_projects" do
    it "returns projects" do
      stub_json_get("#{api_base}/organizations/myorg/projects/",
        body: [{ id: "p1", slug: "web-app", name: "Web App", platform: "javascript", status: "active", dateCreated: "2026-01-01" }])

      result = connector.execute("list_projects")
      expect(result[:projects].first[:slug]).to eq("web-app")
    end
  end

  describe "#execute assign_issue" do
    it "assigns an issue" do
      stub_json_put("#{api_base}/issues/1/",
        body: { id: "1", assignedTo: { name: "Alice" } })

      result = connector.execute("assign_issue", issue_id: "1", assignee: "alice")
      expect(result[:success]).to be true
      expect(result[:assignee]).to eq("Alice")
    end
  end
end
