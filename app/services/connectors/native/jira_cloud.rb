# frozen_string_literal: true

module Connectors
  module Native
    class JiraCloud < Base
      def self.piece_name = "jira-cloud"
      def self.display_name = "Jira Cloud"
      def self.description = "Manage issues, projects, and workflows in Jira Cloud"
      def self.category = "project_management"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/jira.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://auth.atlassian.com/authorize?audience=api.atlassian.com&prompt=consent",
          tokenUrl: "https://auth.atlassian.com/oauth/token",
          scope: "read:jira-work write:jira-work read:jira-user offline_access",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://developer.atlassian.com/console/myapps/",
            "Create > OAuth 2.0 integration",
            "Authorization > Callback URL: {VAULT_URL}/oauth/callback",
            "Permissions > Jira API: read:jira-work, write:jira-work, read:jira-user",
            "Settings > copy Client ID and Secret",
            "Set ENV: VAULT_OAUTH_JIRA_CLOUD_CLIENT_ID and VAULT_OAUTH_JIRA_CLOUD_CLIENT_SECRET"
          ],
          docs_url: "https://developer.atlassian.com/cloud/jira/platform/oauth-2-3lo-apps/"
        }
      end

      def self.actions
        [
          { "name" => "list_projects", "displayName" => "List Projects", "description" => "List Jira projects", "props" => {} },
          { "name" => "search_issues", "displayName" => "Search Issues", "description" => "Search issues with JQL",
            "props" => { "jql" => { "type" => "string", "required" => true, "description" => "JQL query" },
              "max_results" => { "type" => "number", "required" => false } } },
          { "name" => "create_issue", "displayName" => "Create Issue", "description" => "Create a new Jira issue",
            "props" => { "project_key" => { "type" => "string", "required" => true }, "summary" => { "type" => "string", "required" => true },
              "issue_type" => { "type" => "string", "required" => true, "description" => "Task, Bug, Story, Epic" },
              "description" => { "type" => "string", "required" => false } } },
          { "name" => "get_issue", "displayName" => "Get Issue", "description" => "Get issue details by key",
            "props" => { "issue_key" => { "type" => "string", "required" => true, "description" => "e.g., PROJ-123" } } }
        ]
      end

      def execute(action, **params)
        resolve_cloud_id! unless @cloud_id
        case action.to_s
        when "list_projects" then api_get("/rest/api/3/project")
        when "search_issues" then api_post("/rest/api/3/search", { jql: params[:jql], maxResults: params[:max_results] || 20 })
        when "create_issue" then api_post("/rest/api/3/issue", { fields: { project: { key: params[:project_key] }, summary: params[:summary], issuetype: { name: params[:issue_type] }, description: params[:description] ? { type: "doc", version: 1, content: [ { type: "paragraph", content: [ { type: "text", text: params[:description] } ] } ] } : nil }.compact })
        when "get_issue" then api_get("/rest/api/3/issue/#{params[:issue_key]}")
        else raise Connectors::ActionNotFoundError, "Unknown Jira action: #{action}"
        end
      end

      private

      def resolve_cloud_id!
        resp = faraday.get("https://api.atlassian.com/oauth/token/accessible-resources") { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        resources = JSON.parse(resp.body)
        raise Connectors::Error, "No Jira Cloud sites accessible" if resources.empty?
        @cloud_id = resources.first["id"]
      end

      def access_token = credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(path)
        resp = faraday.get("https://api.atlassian.com/ex/jira/#{@cloud_id}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        handle(resp)
      end

      def api_post(path, body)
        resp = faraday.post("https://api.atlassian.com/ex/jira/#{@cloud_id}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Content-Type"] = "application/json"; r.body = body.to_json }
        handle(resp)
      end

      def handle(resp)
        raise Connectors::AuthenticationError, "Jira: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "Jira API error (#{resp.status}): #{data['errorMessages']&.join(', ')}" unless resp.success?
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
