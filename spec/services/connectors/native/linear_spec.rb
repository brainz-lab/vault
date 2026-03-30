# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Linear, type: :service do
  let(:credentials) { { api_key: "lin_test_key" } }
  let(:connector) { described_class.new(credentials) }

  it_behaves_like "a native connector"

  describe "#execute list_issues" do
    it "returns issues" do
      stub_json_post("https://api.linear.app/graphql",
        body: { data: { issues: { nodes: [
          { id: "i1", identifier: "ENG-42", title: "Fix login bug", state: { name: "In Progress" },
            priority: 2, assignee: { displayName: "Alice" }, createdAt: "2026-01-01" }
        ] } } })

      result = connector.execute("list_issues")
      expect(result[:issues].first[:identifier]).to eq("ENG-42")
      expect(result[:issues].first[:state]).to eq("In Progress")
    end
  end

  describe "#execute create_issue" do
    it "creates an issue" do
      stub_json_post("https://api.linear.app/graphql",
        body: { data: { issueCreate: { success: true, issue: { id: "i2", identifier: "ENG-43", title: "New feature", url: "https://linear.app/ENG-43" } } } })

      result = connector.execute("create_issue", team_id: "team1", title: "New feature", priority: 3)
      expect(result[:success]).to be true
      expect(result[:identifier]).to eq("ENG-43")
    end
  end

  describe "#execute list_teams" do
    it "returns teams" do
      stub_json_post("https://api.linear.app/graphql",
        body: { data: { teams: { nodes: [{ id: "t1", key: "ENG", name: "Engineering", issueCount: 150 }] } } })

      result = connector.execute("list_teams")
      expect(result[:teams].first[:key]).to eq("ENG")
    end
  end

  describe "#execute add_comment" do
    it "adds a comment" do
      stub_json_post("https://api.linear.app/graphql",
        body: { data: { commentCreate: { success: true, comment: { id: "cm1" } } } })

      result = connector.execute("add_comment", issue_id: "i1", body: "Looking into this")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises on authentication errors" do
      stub_json_post("https://api.linear.app/graphql",
        body: { errors: [{ message: "authentication required" }] })

      expect { connector.execute("list_issues") }
        .to raise_error(Connectors::AuthenticationError, /Linear/)
    end
  end
end
