# frozen_string_literal: true

module Connectors
  module Native
    class Calendly < Base
      def self.piece_name = "calendly"
      def self.display_name = "Calendly"
      def self.description = "Manage events, invitees, and scheduling in Calendly"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/calendly.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            access_token: { type: "string", description: "Personal Access Token (Integrations → API & Webhooks)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://calendly.com/integrations/api_webhooks",
            "Click 'Get a token now' under Personal Access Tokens",
            "Create and copy the token"
          ],
          docs_url: "https://developer.calendly.com/api-docs"
        }
      end

      def self.actions
        [
          {
            "name" => "list_events",
            "displayName" => "List Events",
            "description" => "List scheduled events",
            "props" => {
              "status" => { "type" => "string", "required" => false, "description" => "Filter: active or canceled (default: active)" },
              "min_start_time" => { "type" => "string", "required" => false, "description" => "Events starting after (ISO 8601)" },
              "max_start_time" => { "type" => "string", "required" => false, "description" => "Events starting before (ISO 8601)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "get_event",
            "displayName" => "Get Event",
            "description" => "Get event details",
            "props" => {
              "event_uuid" => { "type" => "string", "required" => true, "description" => "Event UUID" }
            }
          },
          {
            "name" => "list_invitees",
            "displayName" => "List Invitees",
            "description" => "List invitees for a specific event",
            "props" => {
              "event_uuid" => { "type" => "string", "required" => true, "description" => "Event UUID" },
              "status" => { "type" => "string", "required" => false, "description" => "Filter: active or canceled" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "list_event_types",
            "displayName" => "List Event Types",
            "description" => "List configured event types (meeting templates)",
            "props" => {
              "active" => { "type" => "boolean", "required" => false, "description" => "Filter active only (default: true)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "cancel_event",
            "displayName" => "Cancel Event",
            "description" => "Cancel a scheduled event",
            "props" => {
              "event_uuid" => { "type" => "string", "required" => true, "description" => "Event UUID to cancel" },
              "reason" => { "type" => "string", "required" => false, "description" => "Cancellation reason" }
            }
          },
          {
            "name" => "create_webhook",
            "displayName" => "Create Webhook",
            "description" => "Subscribe to event notifications",
            "props" => {
              "url" => { "type" => "string", "required" => true, "description" => "Webhook callback URL (HTTPS)" },
              "events" => { "type" => "string", "required" => true, "description" => "Comma-separated events: invitee.created, invitee.canceled" },
              "signing_key" => { "type" => "string", "required" => false, "description" => "Webhook signing key for verification" }
            }
          }
        ]
      end

      API_BASE = "https://api.calendly.com"

      def execute(action, **params)
        case action.to_s
        when "list_events" then list_events(params)
        when "get_event" then get_event(params)
        when "list_invitees" then list_invitees(params)
        when "list_event_types" then list_event_types(params)
        when "cancel_event" then cancel_event(params)
        when "create_webhook" then create_webhook(params)
        else raise Connectors::ActionNotFoundError, "Unknown Calendly action: #{action}"
        end
      end

      private

      def list_events(params)
        query = { user: current_user_uri, count: (params[:limit] || 25).to_i }
        query[:status] = params[:status] || "active"
        query[:min_start_time] = params[:min_start_time] if params[:min_start_time].present?
        query[:max_start_time] = params[:max_start_time] if params[:max_start_time].present?

        result = api_get("scheduled_events", query)
        events = (result["collection"] || []).map { |e| format_event(e) }
        { events: events, count: events.size }
      end

      def get_event(params)
        result = api_get("scheduled_events/#{params[:event_uuid]}")
        format_event(result["resource"])
      end

      def list_invitees(params)
        query = { count: (params[:limit] || 25).to_i }
        query[:status] = params[:status] if params[:status].present?

        result = api_get("scheduled_events/#{params[:event_uuid]}/invitees", query)
        invitees = (result["collection"] || []).map do |i|
          { uri: i["uri"], name: i["name"], email: i["email"], status: i["status"],
            timezone: i["timezone"], created_at: i["created_at"],
            questions_and_answers: i["questions_and_answers"] }
        end
        { invitees: invitees, count: invitees.size }
      end

      def list_event_types(params)
        query = { user: current_user_uri, count: (params[:limit] || 25).to_i }
        query[:active] = params[:active] != false

        result = api_get("event_types", query)
        types = (result["collection"] || []).map do |t|
          { uri: t["uri"], name: t["name"], slug: t["slug"], active: t["active"],
            duration: t["duration"], kind: t["kind"], scheduling_url: t["scheduling_url"] }
        end
        { event_types: types, count: types.size }
      end

      def cancel_event(params)
        body = {}
        body[:reason] = params[:reason] if params[:reason].present?

        api_post("scheduled_events/#{params[:event_uuid]}/cancellation", body)
        { success: true, event_uuid: params[:event_uuid] }
      end

      def create_webhook(params)
        events = params[:events].split(",").map(&:strip)
        body = {
          url: params[:url],
          events: events,
          organization: current_org_uri,
          user: current_user_uri,
          scope: "user"
        }
        body[:signing_key] = params[:signing_key] if params[:signing_key].present?

        result = api_post("webhook_subscriptions", body)
        sub = result["resource"]
        { success: true, uri: sub["uri"], callback_url: sub["callback_url"], events: sub["events"] }
      end

      def format_event(e)
        { uri: e["uri"], name: e["name"], status: e["status"],
          start_time: e.dig("start_time"), end_time: e.dig("end_time"),
          event_type: e["event_type"], location: e.dig("location", "location"),
          invitees_counter: e["invitees_counter"], created_at: e["created_at"] }
      end

      def current_user_uri
        @current_user_uri ||= begin
          result = api_get("users/me")
          result.dig("resource", "uri")
        end
      end

      def current_org_uri
        @current_org_uri ||= begin
          result = api_get("users/me")
          result.dig("resource", "current_organization")
        end
      end

      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
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

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data["message"] || data.dig("details", 0, "message") || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Calendly: #{error}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Calendly rate limited" if resp.status == 429
          raise Connectors::Error, "Calendly API error: #{error}"
        end
        data
      end

      def access_token = credentials[:access_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
