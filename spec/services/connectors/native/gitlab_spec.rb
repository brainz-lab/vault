# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Gitlab, type: :service do
  let(:credentials) { { access_token: "gl_test_token", base_url: "https://gitlab.com" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://gitlab.com/api/v4" }

  it_behaves_like "a native connector"

  describe "#execute list_projects" do
    it "returns projects" do
      stub_json_get("#{api_base}/projects",
        body: [{ id: 1, name: "vault", path_with_namespace: "brainzlab/vault",
          default_branch: "main", web_url: "https://gitlab.com/brainzlab/vault", last_activity_at: "2026-01-01" }])

      result = connector.execute("list_projects")
      expect(result[:projects].first[:name]).to eq("vault")
    end
  end

  describe "#execute list_issues" do
    it "returns issues" do
      stub_json_get("#{api_base}/projects/1/issues",
        body: [{ iid: 42, title: "Bug report", state: "opened", labels: ["bug"],
          author: { username: "alice" }, assignees: [{ username: "bob" }],
          web_url: "https://gitlab.com/brainzlab/vault/-/issues/42", created_at: "2026-01-01" }])

      result = connector.execute("list_issues", project_id: "1")
      expect(result[:issues].first[:title]).to eq("Bug report")
      expect(result[:issues].first[:iid]).to eq(42)
    end
  end

  describe "#execute create_issue" do
    it "creates an issue" do
      stub_json_post("#{api_base}/projects/1/issues",
        body: { iid: 43, title: "New feature", web_url: "https://gitlab.com/brainzlab/vault/-/issues/43" })

      result = connector.execute("create_issue", project_id: "1", title: "New feature", labels: "enhancement")
      expect(result[:success]).to be true
      expect(result[:iid]).to eq(43)
    end
  end

  describe "#execute list_merge_requests" do
    it "returns MRs" do
      stub_json_get("#{api_base}/projects/1/merge_requests",
        body: [{ iid: 10, title: "Add feature", state: "opened", source_branch: "feature",
          target_branch: "main", author: { username: "alice" },
          web_url: "https://gitlab.com/brainzlab/vault/-/merge_requests/10", created_at: "2026-01-01" }])

      result = connector.execute("list_merge_requests", project_id: "1")
      expect(result[:merge_requests].first[:title]).to eq("Add feature")
    end
  end

  describe "#execute list_pipelines" do
    it "returns pipelines" do
      stub_json_get("#{api_base}/projects/1/pipelines",
        body: [{ id: 100, status: "success", ref: "main", sha: "abc12345def",
          web_url: "https://gitlab.com/brainzlab/vault/-/pipelines/100", created_at: "2026-01-01" }])

      result = connector.execute("list_pipelines", project_id: "1")
      expect(result[:pipelines].first[:status]).to eq("success")
    end
  end

  describe "supports self-hosted GitLab" do
    it "uses custom base_url" do
      custom = described_class.new({ access_token: "tok", base_url: "https://gitlab.runmyprocess.com" })
      stub_json_get("https://gitlab.runmyprocess.com/api/v4/projects",
        body: [{ id: 1, name: "server", path_with_namespace: "rmp/server",
          default_branch: "work", web_url: "https://gitlab.runmyprocess.com/rmp/server", last_activity_at: "2026-01-01" }])

      result = custom.execute("list_projects")
      expect(result[:projects].first[:name]).to eq("server")
    end
  end
end
