# frozen_string_literal: true

module Connectors
  module Native
    class GithubOauth < Base
      def self.piece_name = "github"
      def self.display_name = "GitHub"
      def self.description = "Manage repositories, issues, and pull requests on GitHub"
      def self.category = "developer"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/github.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://github.com/login/oauth/authorize",
          tokenUrl: "https://github.com/login/oauth/access_token",
          scope: "repo read:user read:org",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://github.com/settings/developers",
            "OAuth Apps > New OAuth App",
            "Set Authorization callback URL to: {VAULT_URL}/oauth/callback",
            "Copy Client ID and generate a Client Secret",
            "Set ENV: VAULT_OAUTH_GITHUB_CLIENT_ID and VAULT_OAUTH_GITHUB_CLIENT_SECRET"
          ],
          docs_url: "https://docs.github.com/en/apps/oauth-apps/building-oauth-apps"
        }
      end

      def self.actions
        [
          { "name" => "list_repos", "displayName" => "List Repositories", "description" => "List repositories for the authenticated user",
            "props" => { "per_page" => { "type" => "number", "required" => false, "description" => "Results per page (default: 30)" } } },
          { "name" => "create_issue", "displayName" => "Create Issue", "description" => "Create an issue in a repository",
            "props" => { "owner" => { "type" => "string", "required" => true }, "repo" => { "type" => "string", "required" => true },
              "title" => { "type" => "string", "required" => true }, "body" => { "type" => "string", "required" => false } } },
          { "name" => "list_issues", "displayName" => "List Issues", "description" => "List issues for a repository",
            "props" => { "owner" => { "type" => "string", "required" => true }, "repo" => { "type" => "string", "required" => true },
              "state" => { "type" => "string", "required" => false, "description" => "open, closed, or all" } } },
          { "name" => "create_pull_request", "displayName" => "Create Pull Request", "description" => "Create a pull request",
            "props" => { "owner" => { "type" => "string", "required" => true }, "repo" => { "type" => "string", "required" => true },
              "title" => { "type" => "string", "required" => true }, "head" => { "type" => "string", "required" => true },
              "base" => { "type" => "string", "required" => true }, "body" => { "type" => "string", "required" => false } } }
        ]
      end

      API = "https://api.github.com"

      def execute(action, **params)
        case action.to_s
        when "list_repos" then api_get("/user/repos?per_page=#{params[:per_page] || 30}")
        when "create_issue" then api_post("/repos/#{params[:owner]}/#{params[:repo]}/issues", { title: params[:title], body: params[:body] })
        when "list_issues" then api_get("/repos/#{params[:owner]}/#{params[:repo]}/issues?state=#{params[:state] || 'open'}")
        when "create_pull_request" then api_post("/repos/#{params[:owner]}/#{params[:repo]}/pulls", params.slice(:title, :head, :base, :body))
        else raise Connectors::ActionNotFoundError, "Unknown GitHub action: #{action}"
        end
      end

      private

      def access_token = credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(path)
        resp = faraday.get("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Accept"] = "application/vnd.github+json" }
        handle(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Content-Type"] = "application/json"; r.body = body.to_json }
        handle(resp)
      end

      def handle(resp)
        raise Connectors::AuthenticationError, "GitHub: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "GitHub API error (#{resp.status}): #{data['message']}" unless resp.success?
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
