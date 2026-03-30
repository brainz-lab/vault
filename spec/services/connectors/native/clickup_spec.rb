# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Clickup, type: :service do
  let(:credentials) { { api_token: "pk_test_token" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.clickup.com/api/v2" }

  it_behaves_like "a native connector"

  describe "#execute list_tasks" do
    it "returns tasks" do
      stub_json_get("#{api_base}/list/l1/task",
        body: { tasks: [{ id: "t1", name: "Fix bug", status: { status: "in progress" },
          priority: { priority: "high" }, assignees: [{ username: "alice" }],
          due_date: "1711929600000", url: "https://app.clickup.com/t/t1" }] })

      result = connector.execute("list_tasks", list_id: "l1")
      expect(result[:tasks].first[:name]).to eq("Fix bug")
      expect(result[:tasks].first[:status]).to eq("in progress")
    end
  end

  describe "#execute create_task" do
    it "creates a task" do
      stub_json_post("#{api_base}/list/l1/task",
        body: { id: "t2", name: "New task", url: "https://app.clickup.com/t/t2" })

      result = connector.execute("create_task", list_id: "l1", name: "New task", priority: 3)
      expect(result[:success]).to be true
      expect(result[:url]).to include("clickup.com")
    end
  end

  describe "#execute update_task" do
    it "updates a task" do
      stub_json_put("#{api_base}/task/t1",
        body: { id: "t1", name: "Fix bug", status: { status: "done" } })

      result = connector.execute("update_task", task_id: "t1", status: "done")
      expect(result[:success]).to be true
    end
  end

  describe "#execute list_workspaces" do
    it "returns workspaces" do
      stub_json_get("#{api_base}/team",
        body: { teams: [{ id: "w1", name: "My Workspace", members: [{}] }] })

      result = connector.execute("list_workspaces")
      expect(result[:workspaces].first[:name]).to eq("My Workspace")
    end
  end

  describe "#execute add_comment" do
    it "adds a comment" do
      stub_json_post("#{api_base}/task/t1/comment", body: { id: "cm1" })

      result = connector.execute("add_comment", task_id: "t1", comment_text: "On it!")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/list/l1/task",
        body: { err: "Token invalid" }, status: 401)

      expect { connector.execute("list_tasks", list_id: "l1") }
        .to raise_error(Connectors::AuthenticationError, /ClickUp/)
    end
  end
end
