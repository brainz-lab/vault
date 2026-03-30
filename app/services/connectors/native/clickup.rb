# frozen_string_literal: true

module Connectors
  module Native
    class Clickup < Base
      def self.piece_name = "clickup"
      def self.display_name = "ClickUp"
      def self.description = "Manage tasks, lists, and spaces in ClickUp"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/clickup.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_token: { type: "string", description: "ClickUp Personal API Token (Settings → Apps)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to ClickUp → Settings → Apps",
            "Under 'API Token', click 'Generate' or copy existing token"
          ],
          docs_url: "https://clickup.com/api/developer-tools/authentication/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_tasks",
            "displayName" => "List Tasks",
            "description" => "List tasks in a list",
            "props" => {
              "list_id" => { "type" => "string", "required" => true, "description" => "List ID" },
              "statuses" => { "type" => "string", "required" => false, "description" => "Comma-separated status names" },
              "assignees" => { "type" => "string", "required" => false, "description" => "Comma-separated assignee IDs" },
              "include_closed" => { "type" => "boolean", "required" => false, "description" => "Include closed tasks (default: false)" }
            }
          },
          {
            "name" => "create_task",
            "displayName" => "Create Task",
            "description" => "Create a new task",
            "props" => {
              "list_id" => { "type" => "string", "required" => true, "description" => "List ID" },
              "name" => { "type" => "string", "required" => true, "description" => "Task name" },
              "description" => { "type" => "string", "required" => false, "description" => "Task description (Markdown)" },
              "priority" => { "type" => "number", "required" => false, "description" => "Priority: 1=urgent, 2=high, 3=normal, 4=low" },
              "assignees" => { "type" => "json", "required" => false, "description" => "Array of assignee user IDs" },
              "due_date" => { "type" => "string", "required" => false, "description" => "Due date (Unix timestamp ms or ISO 8601)" },
              "tags" => { "type" => "json", "required" => false, "description" => "Array of tag names" }
            }
          },
          {
            "name" => "update_task",
            "displayName" => "Update Task",
            "description" => "Update an existing task",
            "props" => {
              "task_id" => { "type" => "string", "required" => true, "description" => "Task ID" },
              "name" => { "type" => "string", "required" => false, "description" => "New name" },
              "description" => { "type" => "string", "required" => false, "description" => "New description" },
              "status" => { "type" => "string", "required" => false, "description" => "New status name" },
              "priority" => { "type" => "number", "required" => false, "description" => "New priority (1-4)" }
            }
          },
          {
            "name" => "add_comment",
            "displayName" => "Add Comment",
            "description" => "Add a comment to a task",
            "props" => {
              "task_id" => { "type" => "string", "required" => true, "description" => "Task ID" },
              "comment_text" => { "type" => "string", "required" => true, "description" => "Comment text" }
            }
          },
          {
            "name" => "list_spaces",
            "displayName" => "List Spaces",
            "description" => "List spaces in a workspace",
            "props" => {
              "team_id" => { "type" => "string", "required" => true, "description" => "Workspace (team) ID" }
            }
          },
          {
            "name" => "list_lists",
            "displayName" => "List Lists",
            "description" => "List lists in a folder or space",
            "props" => {
              "folder_id" => { "type" => "string", "required" => false, "description" => "Folder ID (lists in folder)" },
              "space_id" => { "type" => "string", "required" => false, "description" => "Space ID (folderless lists)" }
            }
          },
          {
            "name" => "list_workspaces",
            "displayName" => "List Workspaces",
            "description" => "List accessible workspaces (teams)",
            "props" => {}
          }
        ]
      end

      API_BASE = "https://api.clickup.com/api/v2"

      def execute(action, **params)
        case action.to_s
        when "list_tasks" then list_tasks(params)
        when "create_task" then create_task(params)
        when "update_task" then update_task(params)
        when "add_comment" then add_comment(params)
        when "list_spaces" then list_spaces(params)
        when "list_lists" then list_lists(params)
        when "list_workspaces" then list_workspaces(params)
        else raise Connectors::ActionNotFoundError, "Unknown ClickUp action: #{action}"
        end
      end

      private

      def list_tasks(params)
        query = {}
        query[:statuses] = params[:statuses].split(",").map(&:strip) if params[:statuses].present?
        query[:assignees] = params[:assignees].split(",").map(&:strip) if params[:assignees].present?
        query[:include_closed] = params[:include_closed] if params.key?(:include_closed)

        result = api_get("list/#{params[:list_id]}/task", query)
        tasks = (result["tasks"] || []).map do |t|
          { id: t["id"], name: t["name"], status: t.dig("status", "status"),
            priority: t.dig("priority", "priority"), assignees: t["assignees"]&.map { |a| a["username"] },
            due_date: t["due_date"], url: t["url"] }
        end
        { tasks: tasks, count: tasks.size }
      end

      def create_task(params)
        body = { name: params[:name] }
        body[:description] = params[:description] if params[:description].present?
        body[:priority] = params[:priority] if params[:priority].present?
        body[:assignees] = parse_json(params[:assignees]) if params[:assignees].present?
        body[:tags] = parse_json(params[:tags]) if params[:tags].present?

        if params[:due_date].present?
          body[:due_date] = params[:due_date].to_s.match?(/^\d+$/) ? params[:due_date].to_i : (Time.parse(params[:due_date]).to_f * 1000).to_i
        end

        result = api_post("list/#{params[:list_id]}/task", body)
        { success: true, id: result["id"], name: result["name"], url: result["url"] }
      end

      def update_task(params)
        body = {}
        body[:name] = params[:name] if params[:name].present?
        body[:description] = params[:description] if params[:description].present?
        body[:status] = params[:status] if params[:status].present?
        body[:priority] = params[:priority] if params[:priority].present?

        result = api_put("task/#{params[:task_id]}", body)
        { success: true, id: result["id"], name: result["name"], status: result.dig("status", "status") }
      end

      def add_comment(params)
        body = { comment_text: params[:comment_text] }
        result = api_post("task/#{params[:task_id]}/comment", body)
        { success: true, id: result["id"] }
      end

      def list_spaces(params)
        result = api_get("team/#{params[:team_id]}/space")
        spaces = (result["spaces"] || []).map do |s|
          { id: s["id"], name: s["name"], private: s["private"], status: s["statuses"]&.map { |st| st["status"] } }
        end
        { spaces: spaces, count: spaces.size }
      end

      def list_lists(params)
        if params[:folder_id].present?
          result = api_get("folder/#{params[:folder_id]}/list")
        elsif params[:space_id].present?
          result = api_get("space/#{params[:space_id]}/list")
        else
          raise Connectors::Error, "Either folder_id or space_id is required"
        end
        lists = (result["lists"] || []).map do |l|
          { id: l["id"], name: l["name"], task_count: l["task_count"], status: l.dig("status", "status") }
        end
        { lists: lists, count: lists.size }
      end

      def list_workspaces(params)
        result = api_get("team")
        teams = (result["teams"] || []).map do |t|
          { id: t["id"], name: t["name"], members_count: t["members"]&.size }
        end
        { workspaces: teams, count: teams.size }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = api_token
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = api_token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = api_token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data["err"] || data["error"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "ClickUp: #{error}" if resp.status == 401
          raise Connectors::RateLimitError, "ClickUp rate limited" if resp.status == 429
          raise Connectors::Error, "ClickUp API error: #{error}"
        end
        data
      end

      def api_token = credentials[:api_token]

      def parse_json(value)
        return value if value.is_a?(Array) || value.is_a?(Hash)
        JSON.parse(value) rescue value
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
