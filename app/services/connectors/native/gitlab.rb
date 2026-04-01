# frozen_string_literal: true

module Connectors
  module Native
    class Gitlab < Base
      def self.piece_name = "gitlab"
      def self.display_name = "GitLab"
      def self.description = "Manage projects, issues, and merge requests in GitLab"
      def self.category = "developer"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/gitlab.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            access_token: { type: "string", description: "Personal Access Token (Settings → Access Tokens)", required: true },
            base_url: { type: "string", description: "GitLab URL (default: https://gitlab.com)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to GitLab → Settings → Access Tokens",
            "Create a token with scopes: api, read_user, read_repository",
            "Copy the token. For self-hosted GitLab, provide the base URL"
          ],
          docs_url: "https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html"
        }
      end

      def self.actions
        [
          {
            "name" => "list_projects",
            "displayName" => "List Projects",
            "description" => "List accessible projects",
            "props" => {
              "search" => { "type" => "string", "required" => false, "description" => "Search query" },
              "owned" => { "type" => "boolean", "required" => false, "description" => "Only owned projects" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "list_issues",
            "displayName" => "List Issues",
            "description" => "List issues in a project",
            "props" => {
              "project_id" => { "type" => "string", "required" => true, "description" => "Project ID or URL-encoded path" },
              "state" => { "type" => "string", "required" => false, "description" => "Filter: opened, closed, all (default: opened)" },
              "labels" => { "type" => "string", "required" => false, "description" => "Comma-separated label names" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "create_issue",
            "displayName" => "Create Issue",
            "description" => "Create a new issue",
            "props" => {
              "project_id" => { "type" => "string", "required" => true, "description" => "Project ID" },
              "title" => { "type" => "string", "required" => true, "description" => "Issue title" },
              "description" => { "type" => "string", "required" => false, "description" => "Issue description (Markdown)" },
              "labels" => { "type" => "string", "required" => false, "description" => "Comma-separated labels" },
              "assignee_ids" => { "type" => "string", "required" => false, "description" => "Comma-separated assignee IDs" },
              "milestone_id" => { "type" => "number", "required" => false, "description" => "Milestone ID" }
            }
          },
          {
            "name" => "list_merge_requests",
            "displayName" => "List Merge Requests",
            "description" => "List merge requests in a project",
            "props" => {
              "project_id" => { "type" => "string", "required" => true, "description" => "Project ID" },
              "state" => { "type" => "string", "required" => false, "description" => "Filter: opened, closed, merged, all (default: opened)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "create_merge_request",
            "displayName" => "Create Merge Request",
            "description" => "Create a new merge request",
            "props" => {
              "project_id" => { "type" => "string", "required" => true, "description" => "Project ID" },
              "title" => { "type" => "string", "required" => true, "description" => "MR title" },
              "source_branch" => { "type" => "string", "required" => true, "description" => "Source branch" },
              "target_branch" => { "type" => "string", "required" => true, "description" => "Target branch" },
              "description" => { "type" => "string", "required" => false, "description" => "MR description (Markdown)" }
            }
          },
          {
            "name" => "list_pipelines",
            "displayName" => "List Pipelines",
            "description" => "List CI/CD pipelines for a project",
            "props" => {
              "project_id" => { "type" => "string", "required" => true, "description" => "Project ID" },
              "status" => { "type" => "string", "required" => false, "description" => "Filter: running, pending, success, failed, canceled" },
              "ref" => { "type" => "string", "required" => false, "description" => "Branch or tag name" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_projects" then list_projects(params)
        when "list_issues" then list_issues(params)
        when "create_issue" then create_issue(params)
        when "list_merge_requests" then list_merge_requests(params)
        when "create_merge_request" then create_merge_request(params)
        when "list_pipelines" then list_pipelines(params)
        else raise Connectors::ActionNotFoundError, "Unknown GitLab action: #{action}"
        end
      end

      private

      def list_projects(params)
        query = { per_page: (params[:limit] || 20).to_i, order_by: "last_activity_at" }
        query[:search] = params[:search] if params[:search].present?
        query[:owned] = true if params[:owned]

        result = api_get("projects", query)
        projects = result.map do |p|
          { id: p["id"], name: p["name"], path_with_namespace: p["path_with_namespace"],
            default_branch: p["default_branch"], web_url: p["web_url"],
            last_activity_at: p["last_activity_at"] }
        end
        { projects: projects, count: projects.size }
      end

      def list_issues(params)
        query = { per_page: (params[:limit] || 20).to_i, state: params[:state] || "opened" }
        query[:labels] = params[:labels] if params[:labels].present?

        result = api_get("projects/#{encode_id(params[:project_id])}/issues", query)
        issues = result.map do |i|
          { iid: i["iid"], title: i["title"], state: i["state"], labels: i["labels"],
            author: i.dig("author", "username"), assignees: i["assignees"]&.map { |a| a["username"] },
            web_url: i["web_url"], created_at: i["created_at"] }
        end
        { issues: issues, count: issues.size }
      end

      def create_issue(params)
        body = { title: params[:title] }
        body[:description] = params[:description] if params[:description].present?
        body[:labels] = params[:labels] if params[:labels].present?
        body[:assignee_ids] = params[:assignee_ids].split(",").map(&:to_i) if params[:assignee_ids].present?
        body[:milestone_id] = params[:milestone_id] if params[:milestone_id].present?

        result = api_post("projects/#{encode_id(params[:project_id])}/issues", body)
        { success: true, iid: result["iid"], title: result["title"], web_url: result["web_url"] }
      end

      def list_merge_requests(params)
        query = { per_page: (params[:limit] || 20).to_i, state: params[:state] || "opened" }
        result = api_get("projects/#{encode_id(params[:project_id])}/merge_requests", query)
        mrs = result.map do |m|
          { iid: m["iid"], title: m["title"], state: m["state"],
            source_branch: m["source_branch"], target_branch: m["target_branch"],
            author: m.dig("author", "username"), web_url: m["web_url"], created_at: m["created_at"] }
        end
        { merge_requests: mrs, count: mrs.size }
      end

      def create_merge_request(params)
        body = { title: params[:title], source_branch: params[:source_branch], target_branch: params[:target_branch] }
        body[:description] = params[:description] if params[:description].present?

        result = api_post("projects/#{encode_id(params[:project_id])}/merge_requests", body)
        { success: true, iid: result["iid"], title: result["title"], web_url: result["web_url"] }
      end

      def list_pipelines(params)
        query = { per_page: (params[:limit] || 20).to_i }
        query[:status] = params[:status] if params[:status].present?
        query[:ref] = params[:ref] if params[:ref].present?

        result = api_get("projects/#{encode_id(params[:project_id])}/pipelines", query)
        pipelines = result.map do |p|
          { id: p["id"], status: p["status"], ref: p["ref"], sha: p["sha"]&.first(8),
            web_url: p["web_url"], created_at: p["created_at"] }
        end
        { pipelines: pipelines, count: pipelines.size }
      end

      def encode_id(id) = ERB::Util.url_encode(id.to_s)

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["PRIVATE-TOKEN"] = access_token
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}") do |req|
          req.headers["PRIVATE-TOKEN"] = access_token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data.is_a?(Hash) ? (data["message"] || data["error"] || "HTTP #{resp.status}") : "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "GitLab: #{error}" if resp.status == 401
          raise Connectors::RateLimitError, "GitLab rate limited" if resp.status == 429
          raise Connectors::Error, "GitLab API error: #{error}"
        end
        data
      end

      def api_base
        base = credentials[:base_url].presence || "https://gitlab.com"
        validate_base_url!(base, label: "GitLab base_url")
        "#{base.chomp('/')}/api/v4"
      end

      def access_token = credentials[:access_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
