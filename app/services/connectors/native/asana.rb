# frozen_string_literal: true

module Connectors
  module Native
    class Asana < Base
      def self.piece_name = "asana"
      def self.display_name = "Asana"
      def self.description = "Manage tasks, projects, and workspaces in Asana"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/asana.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            access_token: { type: "string", description: "Personal Access Token (My Settings → Apps → Developer apps)", required: true },
            workspace_gid: { type: "string", description: "Default workspace GID (optional, auto-detected if only one)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to Asana → My Settings → Apps → Developer apps",
            "Click 'Create new token' under Personal Access Tokens",
            "Copy the generated token",
            "Optionally provide a workspace GID (found in the URL: app.asana.com/0/{workspace_gid}/...)"
          ],
          docs_url: "https://developers.asana.com/docs/personal-access-token"
        }
      end

      def self.actions
        [
          {
            "name" => "list_tasks",
            "displayName" => "List Tasks",
            "description" => "List tasks in a project or assigned to a user",
            "props" => {
              "project_gid" => { "type" => "string", "required" => false, "description" => "Project GID to list tasks from" },
              "assignee" => { "type" => "string", "required" => false, "description" => "Assignee: 'me' or user GID" },
              "completed_since" => { "type" => "string", "required" => false, "description" => "ISO 8601 date — only incomplete or recently completed" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "create_task",
            "displayName" => "Create Task",
            "description" => "Create a new task",
            "props" => {
              "name" => { "type" => "string", "required" => true, "description" => "Task name" },
              "notes" => { "type" => "string", "required" => false, "description" => "Task description (plain text)" },
              "html_notes" => { "type" => "string", "required" => false, "description" => "Task description (HTML)" },
              "project_gid" => { "type" => "string", "required" => false, "description" => "Add to project" },
              "assignee" => { "type" => "string", "required" => false, "description" => "Assignee: 'me' or user GID" },
              "due_on" => { "type" => "string", "required" => false, "description" => "Due date (YYYY-MM-DD)" },
              "tags" => { "type" => "string", "required" => false, "description" => "Comma-separated tag GIDs" }
            }
          },
          {
            "name" => "update_task",
            "displayName" => "Update Task",
            "description" => "Update an existing task",
            "props" => {
              "task_gid" => { "type" => "string", "required" => true, "description" => "Task GID" },
              "name" => { "type" => "string", "required" => false, "description" => "New name" },
              "notes" => { "type" => "string", "required" => false, "description" => "New description" },
              "completed" => { "type" => "boolean", "required" => false, "description" => "Mark as completed" },
              "assignee" => { "type" => "string", "required" => false, "description" => "New assignee" },
              "due_on" => { "type" => "string", "required" => false, "description" => "New due date (YYYY-MM-DD)" }
            }
          },
          {
            "name" => "add_comment",
            "displayName" => "Add Comment",
            "description" => "Add a comment (story) to a task",
            "props" => {
              "task_gid" => { "type" => "string", "required" => true, "description" => "Task GID" },
              "text" => { "type" => "string", "required" => true, "description" => "Comment text" }
            }
          },
          {
            "name" => "list_projects",
            "displayName" => "List Projects",
            "description" => "List projects in a workspace",
            "props" => {
              "workspace_gid" => { "type" => "string", "required" => false, "description" => "Workspace GID (uses default if omitted)" },
              "archived" => { "type" => "boolean", "required" => false, "description" => "Include archived projects (default: false)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "list_workspaces",
            "displayName" => "List Workspaces",
            "description" => "List all accessible workspaces",
            "props" => {}
          },
          {
            "name" => "search_tasks",
            "displayName" => "Search Tasks",
            "description" => "Search tasks in a workspace",
            "props" => {
              "text" => { "type" => "string", "required" => true, "description" => "Search text" },
              "workspace_gid" => { "type" => "string", "required" => false, "description" => "Workspace GID (uses default if omitted)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          }
        ]
      end

      API_BASE = "https://app.asana.com/api/1.0"

      def execute(action, **params)
        case action.to_s
        when "list_tasks" then list_tasks(params)
        when "create_task" then create_task(params)
        when "update_task" then update_task(params)
        when "add_comment" then add_comment(params)
        when "list_projects" then list_projects(params)
        when "list_workspaces" then list_workspaces(params)
        when "search_tasks" then search_tasks(params)
        else raise Connectors::ActionNotFoundError, "Unknown Asana action: #{action}"
        end
      end

      private

      def list_tasks(params)
        query = { limit: (params[:limit] || 50).to_i, opt_fields: "name,completed,due_on,assignee.name,created_at" }

        if params[:project_gid].present?
          query[:project] = params[:project_gid]
        elsif params[:assignee].present?
          query[:assignee] = params[:assignee]
          query[:workspace] = resolve_workspace(params)
        else
          query[:assignee] = "me"
          query[:workspace] = resolve_workspace(params)
        end

        query[:completed_since] = params[:completed_since] if params[:completed_since].present?

        result = api_get("tasks", query)
        tasks = (result["data"] || []).map do |t|
          { gid: t["gid"], name: t["name"], completed: t["completed"],
            due_on: t["due_on"], assignee: t.dig("assignee", "name") }
        end
        { tasks: tasks, count: tasks.size }
      end

      def create_task(params)
        body = { name: params[:name] }
        body[:notes] = params[:notes] if params[:notes].present?
        body[:html_notes] = params[:html_notes] if params[:html_notes].present?
        body[:assignee] = params[:assignee] if params[:assignee].present?
        body[:due_on] = params[:due_on] if params[:due_on].present?
        body[:workspace] = resolve_workspace(params)

        if params[:project_gid].present?
          body[:projects] = [params[:project_gid]]
        end

        if params[:tags].present?
          body[:tags] = params[:tags].split(",").map(&:strip)
        end

        result = api_post("tasks", { data: body })
        t = result["data"]
        { success: true, gid: t["gid"], name: t["name"] }
      end

      def update_task(params)
        body = {}
        body[:name] = params[:name] if params[:name].present?
        body[:notes] = params[:notes] if params[:notes].present?
        body[:completed] = params[:completed] if params.key?(:completed)
        body[:assignee] = params[:assignee] if params[:assignee].present?
        body[:due_on] = params[:due_on] if params[:due_on].present?

        result = api_put("tasks/#{params[:task_gid]}", { data: body })
        t = result["data"]
        { success: true, gid: t["gid"], name: t["name"], completed: t["completed"] }
      end

      def add_comment(params)
        body = { data: { text: params[:text] } }
        result = api_post("tasks/#{params[:task_gid]}/stories", body)
        { success: true, gid: result.dig("data", "gid") }
      end

      def list_projects(params)
        query = { workspace: resolve_workspace(params), limit: (params[:limit] || 50).to_i,
                  opt_fields: "name,archived,created_at,current_status.text" }
        query[:archived] = params[:archived] if params.key?(:archived)

        result = api_get("projects", query)
        projects = (result["data"] || []).map do |p|
          { gid: p["gid"], name: p["name"], archived: p["archived"], status: p.dig("current_status", "text") }
        end
        { projects: projects, count: projects.size }
      end

      def list_workspaces(params)
        result = api_get("workspaces")
        workspaces = (result["data"] || []).map { |w| { gid: w["gid"], name: w["name"] } }
        { workspaces: workspaces, count: workspaces.size }
      end

      def search_tasks(params)
        query = { "text" => params[:text], "opt_fields" => "name,completed,due_on,assignee.name" }
        ws = resolve_workspace(params)
        result = api_get("workspaces/#{ws}/tasks/search", query)
        tasks = (result["data"] || []).first((params[:limit] || 25).to_i).map do |t|
          { gid: t["gid"], name: t["name"], completed: t["completed"],
            due_on: t["due_on"], assignee: t.dig("assignee", "name") }
        end
        { tasks: tasks, count: tasks.size }
      end

      def resolve_workspace(params)
        params[:workspace_gid] || default_workspace_gid || auto_detect_workspace
      end

      def auto_detect_workspace
        @auto_workspace ||= begin
          result = api_get("workspaces")
          workspaces = result["data"] || []
          raise Connectors::Error, "No workspaces found. Provide workspace_gid." if workspaces.empty?
          workspaces.first["gid"]
        end
      end

      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          errors = data["errors"]&.map { |e| e["message"] }&.join(", ") || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Asana: #{errors}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Asana rate limited" if resp.status == 429
          raise Connectors::Error, "Asana API error: #{errors}"
        end
        data
      end

      def access_token = credentials[:access_token]
      def default_workspace_gid = credentials[:workspace_gid]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
