# frozen_string_literal: true

module Connectors
  module Native
    class Linear < Base
      def self.piece_name = "linear"
      def self.display_name = "Linear"
      def self.description = "Manage issues, projects, and cycles in Linear"
      def self.category = "project_management"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/linear.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_key: { type: "string", description: "Linear API Key (Settings → API → Personal API keys)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to Linear → Settings → API → Personal API keys",
            "Click 'Create key', give it a label, and copy the key"
          ],
          docs_url: "https://developers.linear.app/docs/graphql/working-with-the-graphql-api"
        }
      end

      def self.actions
        [
          {
            "name" => "list_issues",
            "displayName" => "List Issues",
            "description" => "List issues with optional filtering",
            "props" => {
              "team_key" => { "type" => "string", "required" => false, "description" => "Team key to filter (e.g., ENG)" },
              "state" => { "type" => "string", "required" => false, "description" => "Filter by state name (e.g., In Progress, Done)" },
              "assignee" => { "type" => "string", "required" => false, "description" => "Filter by assignee display name" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "create_issue",
            "displayName" => "Create Issue",
            "description" => "Create a new issue",
            "props" => {
              "team_id" => { "type" => "string", "required" => true, "description" => "Team ID" },
              "title" => { "type" => "string", "required" => true, "description" => "Issue title" },
              "description" => { "type" => "string", "required" => false, "description" => "Issue description (Markdown)" },
              "priority" => { "type" => "number", "required" => false, "description" => "Priority: 0=none, 1=urgent, 2=high, 3=medium, 4=low" },
              "assignee_id" => { "type" => "string", "required" => false, "description" => "Assignee user ID" },
              "label_ids" => { "type" => "json", "required" => false, "description" => "Array of label IDs" }
            }
          },
          {
            "name" => "update_issue",
            "displayName" => "Update Issue",
            "description" => "Update an existing issue",
            "props" => {
              "issue_id" => { "type" => "string", "required" => true, "description" => "Issue ID" },
              "title" => { "type" => "string", "required" => false, "description" => "New title" },
              "state_id" => { "type" => "string", "required" => false, "description" => "New state ID" },
              "priority" => { "type" => "number", "required" => false, "description" => "New priority (0-4)" },
              "assignee_id" => { "type" => "string", "required" => false, "description" => "New assignee ID" }
            }
          },
          {
            "name" => "list_teams",
            "displayName" => "List Teams",
            "description" => "List all teams",
            "props" => {}
          },
          {
            "name" => "list_projects",
            "displayName" => "List Projects",
            "description" => "List projects",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "add_comment",
            "displayName" => "Add Comment",
            "description" => "Add a comment to an issue",
            "props" => {
              "issue_id" => { "type" => "string", "required" => true, "description" => "Issue ID" },
              "body" => { "type" => "string", "required" => true, "description" => "Comment body (Markdown)" }
            }
          }
        ]
      end

      API_URL = "https://api.linear.app/graphql"

      def execute(action, **params)
        case action.to_s
        when "list_issues" then list_issues(params)
        when "create_issue" then create_issue(params)
        when "update_issue" then update_issue(params)
        when "list_teams" then list_teams(params)
        when "list_projects" then list_projects(params)
        when "add_comment" then add_comment(params)
        else raise Connectors::ActionNotFoundError, "Unknown Linear action: #{action}"
        end
      end

      private

      def list_issues(params)
        limit = (params[:limit] || 25).to_i
        filter = {}
        filter[:team] = { key: { eq: params[:team_key] } } if params[:team_key].present?
        filter[:state] = { name: { eq: params[:state] } } if params[:state].present?
        filter[:assignee] = { displayName: { eq: params[:assignee] } } if params[:assignee].present?

        vars = { first: limit }
        vars[:filter] = filter if filter.any?

        q = filter.any? ? "query($first: Int!, $filter: IssueFilter)" : "query($first: Int!)"
        args = filter.any? ? "(first: $first, filter: $filter)" : "(first: $first)"

        result = graphql(
          "#{q} { issues#{args} { nodes { id identifier title state { name } priority assignee { displayName } createdAt updatedAt } } }",
          variables: vars
        )
        issues = (result.dig("data", "issues", "nodes") || []).map do |i|
          { id: i["id"], identifier: i["identifier"], title: i["title"],
            state: i.dig("state", "name"), priority: i["priority"],
            assignee: i.dig("assignee", "displayName"), created_at: i["createdAt"] }
        end
        { issues: issues, count: issues.size }
      end

      def create_issue(params)
        input = { teamId: params[:team_id], title: params[:title] }
        input[:description] = params[:description] if params[:description].present?
        input[:priority] = params[:priority].to_i if params[:priority].present?
        input[:assigneeId] = params[:assignee_id] if params[:assignee_id].present?

        label_ids = parse_json(params[:label_ids])
        input[:labelIds] = label_ids if label_ids.is_a?(Array) && label_ids.any?

        result = graphql(
          "mutation($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { id identifier title url } } }",
          variables: { input: input }
        )
        issue = result.dig("data", "issueCreate", "issue")
        { success: true, id: issue["id"], identifier: issue["identifier"], title: issue["title"], url: issue["url"] }
      end

      def update_issue(params)
        input = {}
        input[:title] = params[:title] if params[:title].present?
        input[:stateId] = params[:state_id] if params[:state_id].present?
        input[:priority] = params[:priority].to_i if params[:priority].present?
        input[:assigneeId] = params[:assignee_id] if params[:assignee_id].present?

        result = graphql(
          "mutation($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success issue { id identifier title state { name } } } }",
          variables: { id: params[:issue_id].to_s, input: input }
        )
        issue = result.dig("data", "issueUpdate", "issue")
        { success: true, id: issue["id"], identifier: issue["identifier"], state: issue.dig("state", "name") }
      end

      def list_teams(params)
        result = graphql("{ teams { nodes { id key name issueCount } } }")
        teams = (result.dig("data", "teams", "nodes") || []).map do |t|
          { id: t["id"], key: t["key"], name: t["name"], issue_count: t["issueCount"] }
        end
        { teams: teams, count: teams.size }
      end

      def list_projects(params)
        limit = (params[:limit] || 25).to_i
        result = graphql(
          "query($first: Int!) { projects(first: $first) { nodes { id name state startDate targetDate } } }",
          variables: { first: limit }
        )
        projects = (result.dig("data", "projects", "nodes") || []).map do |p|
          { id: p["id"], name: p["name"], state: p["state"],
            start_date: p["startDate"], target_date: p["targetDate"] }
        end
        { projects: projects, count: projects.size }
      end

      def add_comment(params)
        result = graphql(
          "mutation($input: CommentCreateInput!) { commentCreate(input: $input) { success comment { id } } }",
          variables: { input: { issueId: params[:issue_id].to_s, body: params[:body].to_s } }
        )
        { success: true, comment_id: result.dig("data", "commentCreate", "comment", "id") }
      end

      def graphql(query, variables: {})
        resp = faraday.post(API_URL) do |req|
          req.headers["Authorization"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = { query: query, variables: variables }.to_json
        end

        data = JSON.parse(resp.body)
        if data["errors"].present?
          error = data["errors"].map { |e| e["message"] }.join(", ")
          raise Connectors::AuthenticationError, "Linear: #{error}" if error.include?("authentication")
          raise Connectors::Error, "Linear API error: #{error}"
        end
        raise Connectors::RateLimitError, "Linear rate limited" if resp.status == 429
        raise Connectors::Error, "Linear HTTP #{resp.status}" unless resp.success?
        data
      end

      def to_gql_input(hash)
        pairs = hash.map do |k, v|
          case v
          when String then "#{k}: \"#{escape_gql(v)}\""
          when Integer, Float then "#{k}: #{v}"
          when Array then "#{k}: #{v.map { |i| "\"#{i}\"" }}"
          when TrueClass, FalseClass then "#{k}: #{v}"
          else "#{k}: \"#{escape_gql(v.to_s)}\""
          end
        end
        "{ #{pairs.join(', ')} }"
      end

      def escape_gql(str) = str.to_s.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("\n", '\\n')
      def api_key = credentials[:api_key]

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
