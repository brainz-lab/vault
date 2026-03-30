# frozen_string_literal: true

module Connectors
  module Native
    class Sentry < Base
      def self.piece_name = "sentry"
      def self.display_name = "Sentry"
      def self.description = "Monitor errors and issues in Sentry"
      def self.category = "developer"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/sentry.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            auth_token: { type: "string", description: "Sentry Auth Token (Settings → Auth Tokens)", required: true },
            organization_slug: { type: "string", description: "Organization slug (from your Sentry URL)", required: true },
            base_url: { type: "string", description: "Sentry URL (default: https://sentry.io)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to Sentry → Settings → Auth Tokens → Create New Token",
            "Select scopes: project:read, issue:read, issue:write, event:read, org:read",
            "Copy the token and your organization slug from the URL"
          ],
          docs_url: "https://docs.sentry.io/api/auth/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_issues",
            "displayName" => "List Issues",
            "description" => "List issues for a project",
            "props" => {
              "project_slug" => { "type" => "string", "required" => true, "description" => "Project slug" },
              "query" => { "type" => "string", "required" => false, "description" => "Search query (e.g., is:unresolved, assigned:me)" },
              "sort" => { "type" => "string", "required" => false, "description" => "Sort: date, new, priority, freq, user (default: date)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "get_issue",
            "displayName" => "Get Issue",
            "description" => "Get issue details",
            "props" => {
              "issue_id" => { "type" => "string", "required" => true, "description" => "Issue ID" }
            }
          },
          {
            "name" => "resolve_issue",
            "displayName" => "Resolve Issue",
            "description" => "Mark an issue as resolved",
            "props" => {
              "issue_id" => { "type" => "string", "required" => true, "description" => "Issue ID" }
            }
          },
          {
            "name" => "list_projects",
            "displayName" => "List Projects",
            "description" => "List projects in the organization",
            "props" => {}
          },
          {
            "name" => "list_events",
            "displayName" => "List Events",
            "description" => "List recent events for an issue",
            "props" => {
              "issue_id" => { "type" => "string", "required" => true, "description" => "Issue ID" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 10)" }
            }
          },
          {
            "name" => "assign_issue",
            "displayName" => "Assign Issue",
            "description" => "Assign an issue to a team member",
            "props" => {
              "issue_id" => { "type" => "string", "required" => true, "description" => "Issue ID" },
              "assignee" => { "type" => "string", "required" => true, "description" => "Username or email of assignee" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_issues" then list_issues(params)
        when "get_issue" then get_issue(params)
        when "resolve_issue" then resolve_issue(params)
        when "list_projects" then list_projects(params)
        when "list_events" then list_events(params)
        when "assign_issue" then assign_issue(params)
        else raise Connectors::ActionNotFoundError, "Unknown Sentry action: #{action}"
        end
      end

      private

      def list_issues(params)
        query = { query: params[:query] || "is:unresolved" }
        query[:sort] = params[:sort] if params[:sort].present?

        result = api_get("projects/#{org}/#{params[:project_slug]}/issues/", query)
        issues = result.first((params[:limit] || 25).to_i).map { |i| format_issue(i) }
        { issues: issues, count: issues.size }
      end

      def get_issue(params)
        result = api_get("issues/#{params[:issue_id]}/")
        format_issue(result)
      end

      def resolve_issue(params)
        result = api_put("issues/#{params[:issue_id]}/", { status: "resolved" })
        { success: true, id: result["id"], status: result["status"] }
      end

      def list_projects(params)
        result = api_get("organizations/#{org}/projects/")
        projects = result.map do |p|
          { id: p["id"], slug: p["slug"], name: p["name"], platform: p["platform"],
            status: p["status"], dateCreated: p["dateCreated"] }
        end
        { projects: projects, count: projects.size }
      end

      def list_events(params)
        result = api_get("issues/#{params[:issue_id]}/events/")
        events = result.first((params[:limit] || 10).to_i).map do |e|
          { id: e["id"], event_id: e["eventID"], title: e["title"], message: e["message"]&.truncate(200),
            platform: e["platform"], dateCreated: e["dateCreated"],
            tags: e["tags"]&.to_h { |t| [t["key"], t["value"]] } }
        end
        { events: events, count: events.size }
      end

      def assign_issue(params)
        result = api_put("issues/#{params[:issue_id]}/", { assignedTo: params[:assignee] })
        { success: true, id: result["id"], assignee: result.dig("assignedTo", "name") }
      end

      def format_issue(i)
        { id: i["id"], title: i["title"], culprit: i["culprit"], status: i["status"],
          level: i["level"], count: i["count"], userCount: i["userCount"],
          first_seen: i["firstSeen"], last_seen: i["lastSeen"],
          assignee: i.dig("assignedTo", "name"), permalink: i["permalink"] }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{auth_token}"
          req.params = params
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{auth_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data.is_a?(Hash) ? (data["detail"] || "HTTP #{resp.status}") : "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Sentry: #{error}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Sentry rate limited" if resp.status == 429
          raise Connectors::Error, "Sentry API error: #{error}"
        end
        data
      end

      def api_base
        base = credentials[:base_url].presence || "https://sentry.io"
        "#{base.chomp('/')}/api/0"
      end

      def org = credentials[:organization_slug]
      def auth_token = credentials[:auth_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
