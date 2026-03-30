# frozen_string_literal: true

module Connectors
  module Native
    class Typeform < Base
      def self.piece_name = "typeform"
      def self.display_name = "Typeform"
      def self.description = "Manage forms and retrieve responses from Typeform"
      def self.category = "forms_and_surveys"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/typeform.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            access_token: { type: "string", description: "Personal Access Token (Account → Personal tokens)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://admin.typeform.com/account#/section/tokens",
            "Click 'Generate a new token'",
            "Select scopes: forms:read, responses:read, workspaces:read",
            "Copy the generated token"
          ],
          docs_url: "https://www.typeform.com/developers/get-started/personal-access-token/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_forms",
            "displayName" => "List Forms",
            "description" => "List all forms",
            "props" => {
              "workspace_id" => { "type" => "string", "required" => false, "description" => "Filter by workspace ID" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "get_form",
            "displayName" => "Get Form",
            "description" => "Get form details with fields",
            "props" => {
              "form_id" => { "type" => "string", "required" => true, "description" => "Form ID" }
            }
          },
          {
            "name" => "list_responses",
            "displayName" => "List Responses",
            "description" => "Get responses for a form",
            "props" => {
              "form_id" => { "type" => "string", "required" => true, "description" => "Form ID" },
              "since" => { "type" => "string", "required" => false, "description" => "Responses since (ISO 8601 datetime)" },
              "until" => { "type" => "string", "required" => false, "description" => "Responses until (ISO 8601 datetime)" },
              "completed" => { "type" => "boolean", "required" => false, "description" => "Only completed responses (default: true)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max responses (default: 25)" }
            }
          },
          {
            "name" => "get_response_count",
            "displayName" => "Get Response Count",
            "description" => "Get total response count for a form",
            "props" => {
              "form_id" => { "type" => "string", "required" => true, "description" => "Form ID" }
            }
          },
          {
            "name" => "list_workspaces",
            "displayName" => "List Workspaces",
            "description" => "List all workspaces",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          }
        ]
      end

      API_BASE = "https://api.typeform.com"

      def execute(action, **params)
        case action.to_s
        when "list_forms" then list_forms(params)
        when "get_form" then get_form(params)
        when "list_responses" then list_responses(params)
        when "get_response_count" then get_response_count(params)
        when "list_workspaces" then list_workspaces(params)
        else raise Connectors::ActionNotFoundError, "Unknown Typeform action: #{action}"
        end
      end

      private

      def list_forms(params)
        query = { page_size: (params[:limit] || 25).to_i }
        query[:workspace_id] = params[:workspace_id] if params[:workspace_id].present?

        result = api_get("forms", query)
        forms = (result["items"] || []).map do |f|
          { id: f["id"], title: f["title"], status: f["status"],
            responses: f.dig("_links", "responses"), created_at: f["created_at"] }
        end
        { forms: forms, count: forms.size, total: result["total_items"] }
      end

      def get_form(params)
        result = api_get("forms/#{params[:form_id]}")
        fields = (result["fields"] || []).map do |f|
          { id: f["id"], ref: f["ref"], title: f["title"], type: f["type"],
            required: f.dig("validations", "required") }
        end
        { id: result["id"], title: result["title"], status: result["status"],
          fields: fields, fields_count: fields.size }
      end

      def list_responses(params)
        query = { page_size: (params[:limit] || 25).to_i }
        query[:since] = params[:since] if params[:since].present?
        query[:until] = params[:until] if params[:until].present?
        query[:completed] = params[:completed] != false

        result = api_get("forms/#{params[:form_id]}/responses", query)
        responses = (result["items"] || []).map do |r|
          answers = (r["answers"] || []).map do |a|
            value = a[a["type"]] || a.dig(a["type"], "label") || a.dig(a["type"], "labels")
            { field_ref: a.dig("field", "ref"), field_type: a.dig("field", "type"),
              type: a["type"], value: value }
          end
          { response_id: r["response_id"], landed_at: r["landed_at"],
            submitted_at: r["submitted_at"], answers: answers }
        end
        { responses: responses, count: responses.size, total: result["total_items"] }
      end

      def get_response_count(params)
        result = api_get("forms/#{params[:form_id]}/responses", page_size: 1)
        { form_id: params[:form_id], total_responses: result["total_items"] }
      end

      def list_workspaces(params)
        query = { page_size: (params[:limit] || 25).to_i }
        result = api_get("workspaces", query)
        workspaces = (result["items"] || []).map do |w|
          { id: w["id"], name: w["name"], forms_count: w.dig("forms", "count") }
        end
        { workspaces: workspaces, count: workspaces.size }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.params = params
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data["description"] || data["message"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Typeform: #{error}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Typeform rate limited" if resp.status == 429
          raise Connectors::Error, "Typeform API error: #{error}"
        end
        data
      end

      def access_token = credentials[:access_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
