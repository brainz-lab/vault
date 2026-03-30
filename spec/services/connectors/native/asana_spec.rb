# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Asana, type: :service do
  let(:credentials) { { access_token: "asana_test_token", workspace_gid: "ws123" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://app.asana.com/api/1.0" }

  it_behaves_like "a native connector"

  describe "#execute list_tasks" do
    it "returns tasks assigned to me" do
      stub_json_get("#{api_base}/tasks",
        body: { data: [{ gid: "t1", name: "Fix bug", completed: false, due_on: "2026-04-01",
          assignee: { name: "Alice" } }] })

      result = connector.execute("list_tasks")
      expect(result[:tasks].first[:name]).to eq("Fix bug")
    end
  end

  describe "#execute create_task" do
    it "creates a task" do
      stub_json_post("#{api_base}/tasks",
        body: { data: { gid: "t2", name: "New task" } })

      result = connector.execute("create_task", name: "New task", due_on: "2026-04-15")
      expect(result[:success]).to be true
      expect(result[:gid]).to eq("t2")
    end
  end

  describe "#execute update_task" do
    it "completes a task" do
      stub_json_put("#{api_base}/tasks/t1",
        body: { data: { gid: "t1", name: "Fix bug", completed: true } })

      result = connector.execute("update_task", task_gid: "t1", completed: true)
      expect(result[:success]).to be true
      expect(result[:completed]).to be true
    end
  end

  describe "#execute add_comment" do
    it "adds a comment" do
      stub_json_post("#{api_base}/tasks/t1/stories",
        body: { data: { gid: "s1" } })

      result = connector.execute("add_comment", task_gid: "t1", text: "Looking into this")
      expect(result[:success]).to be true
    end
  end

  describe "#execute list_projects" do
    it "returns projects" do
      stub_json_get("#{api_base}/projects",
        body: { data: [{ gid: "p1", name: "Project X", archived: false, current_status: { text: "On track" } }] })

      result = connector.execute("list_projects")
      expect(result[:projects].first[:name]).to eq("Project X")
    end
  end

  describe "#execute list_workspaces" do
    it "returns workspaces" do
      stub_json_get("#{api_base}/workspaces",
        body: { data: [{ gid: "ws123", name: "My Workspace" }] })

      result = connector.execute("list_workspaces")
      expect(result[:workspaces].first[:name]).to eq("My Workspace")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/tasks",
        body: { errors: [{ message: "Not authorized" }] }, status: 401)

      expect { connector.execute("list_tasks") }
        .to raise_error(Connectors::AuthenticationError, /Asana/)
    end
  end
end
