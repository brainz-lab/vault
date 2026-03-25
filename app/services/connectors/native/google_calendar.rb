# frozen_string_literal: true

module Connectors
  module Native
    class GoogleCalendar < Base
      def self.piece_name = "google-calendar"
      def self.display_name = "Google Calendar"
      def self.description = "Manage events and calendars in Google Calendar"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/google-calendar.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent",
          tokenUrl: "https://oauth2.googleapis.com/token",
          scope: "https://www.googleapis.com/auth/calendar",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://console.cloud.google.com and create or select a project",
            "Enable the Google Calendar API in APIs & Services > Library",
            "Configure the OAuth consent screen (APIs & Services > OAuth consent screen)",
            "Create OAuth credentials: APIs & Services > Credentials > Create Credentials > OAuth client ID",
            "Set Authorized redirect URI to: {VAULT_URL}/oauth/callback",
            "Copy Client ID and Client Secret",
            "Set ENV: VAULT_OAUTH_GOOGLE_CALENDAR_CLIENT_ID and VAULT_OAUTH_GOOGLE_CALENDAR_CLIENT_SECRET"
          ],
          docs_url: "https://developers.google.com/calendar/api/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "list_events",
            "displayName" => "List Events",
            "description" => "List upcoming events from a calendar",
            "props" => {
              "calendar_id" => { "type" => "string", "required" => false, "description" => "Calendar ID (default: primary)" },
              "time_min" => { "type" => "string", "required" => false, "description" => "Start time filter (ISO 8601, e.g. 2025-01-01T00:00:00Z)" },
              "time_max" => { "type" => "string", "required" => false, "description" => "End time filter (ISO 8601)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" },
              "query" => { "type" => "string", "required" => false, "description" => "Free text search" }
            }
          },
          {
            "name" => "get_event",
            "displayName" => "Get Event",
            "description" => "Get details of a specific event",
            "props" => {
              "calendar_id" => { "type" => "string", "required" => false, "description" => "Calendar ID (default: primary)" },
              "event_id" => { "type" => "string", "required" => true, "description" => "Event ID" }
            }
          },
          {
            "name" => "create_event",
            "displayName" => "Create Event",
            "description" => "Create a new calendar event",
            "props" => {
              "calendar_id" => { "type" => "string", "required" => false, "description" => "Calendar ID (default: primary)" },
              "summary" => { "type" => "string", "required" => true, "description" => "Event title" },
              "description" => { "type" => "string", "required" => false, "description" => "Event description" },
              "location" => { "type" => "string", "required" => false, "description" => "Event location" },
              "start_time" => { "type" => "string", "required" => true, "description" => "Start time (ISO 8601, e.g. 2025-03-25T10:00:00-05:00)" },
              "end_time" => { "type" => "string", "required" => true, "description" => "End time (ISO 8601)" },
              "timezone" => { "type" => "string", "required" => false, "description" => "Timezone (e.g. America/New_York, default: UTC)" },
              "attendees" => { "type" => "json", "required" => false, "description" => "Array of attendee emails [\"email1@example.com\"]" },
              "send_notifications" => { "type" => "boolean", "required" => false, "description" => "Send invite notifications (default: true)" }
            }
          },
          {
            "name" => "update_event",
            "displayName" => "Update Event",
            "description" => "Update an existing calendar event",
            "props" => {
              "calendar_id" => { "type" => "string", "required" => false, "description" => "Calendar ID (default: primary)" },
              "event_id" => { "type" => "string", "required" => true, "description" => "Event ID" },
              "summary" => { "type" => "string", "required" => false, "description" => "New event title" },
              "description" => { "type" => "string", "required" => false, "description" => "New description" },
              "location" => { "type" => "string", "required" => false, "description" => "New location" },
              "start_time" => { "type" => "string", "required" => false, "description" => "New start time (ISO 8601)" },
              "end_time" => { "type" => "string", "required" => false, "description" => "New end time (ISO 8601)" },
              "timezone" => { "type" => "string", "required" => false, "description" => "Timezone" }
            }
          },
          {
            "name" => "delete_event",
            "displayName" => "Delete Event",
            "description" => "Delete a calendar event",
            "props" => {
              "calendar_id" => { "type" => "string", "required" => false, "description" => "Calendar ID (default: primary)" },
              "event_id" => { "type" => "string", "required" => true, "description" => "Event ID" }
            }
          },
          {
            "name" => "list_calendars",
            "displayName" => "List Calendars",
            "description" => "List all calendars accessible to the user",
            "props" => {}
          },
          {
            "name" => "check_availability",
            "displayName" => "Check Availability",
            "description" => "Check free/busy status for calendars",
            "props" => {
              "time_min" => { "type" => "string", "required" => true, "description" => "Start of time range (ISO 8601)" },
              "time_max" => { "type" => "string", "required" => true, "description" => "End of time range (ISO 8601)" },
              "calendars" => { "type" => "json", "required" => false, "description" => "Array of calendar IDs (default: [\"primary\"])" }
            }
          }
        ]
      end

      CALENDAR_API = "https://www.googleapis.com/calendar/v3"

      def execute(action, **params)
        case action.to_s
        when "list_events" then list_events(params)
        when "get_event" then get_event(params)
        when "create_event" then create_event(params)
        when "update_event" then update_event(params)
        when "delete_event" then delete_event(params)
        when "list_calendars" then list_calendars(params)
        when "check_availability" then check_availability(params)
        else raise Connectors::ActionNotFoundError, "Unknown Google Calendar action: #{action}"
        end
      end

      private

      def list_events(params)
        calendar_id = params[:calendar_id] || "primary"
        limit = (params[:limit] || 20).to_i

        query_params = { maxResults: limit, singleEvents: true, orderBy: "startTime" }
        query_params[:timeMin] = params[:time_min] if params[:time_min].present?
        query_params[:timeMax] = params[:time_max] if params[:time_max].present?
        query_params[:q] = params[:query] if params[:query].present?

        url = "#{CALENDAR_API}/calendars/#{CGI.escape(calendar_id)}/events?#{URI.encode_www_form(query_params)}"
        resp = api_get(url)

        events = (resp["items"] || []).map { |e| format_event(e) }
        { events: events, count: events.size }
      end

      def get_event(params)
        calendar_id = params[:calendar_id] || "primary"
        resp = api_get("#{CALENDAR_API}/calendars/#{CGI.escape(calendar_id)}/events/#{params[:event_id]}")
        format_event(resp)
      end

      def create_event(params)
        calendar_id = params[:calendar_id] || "primary"
        timezone = params[:timezone] || "UTC"

        body = {
          summary: params[:summary],
          start: { dateTime: params[:start_time], timeZone: timezone },
          end: { dateTime: params[:end_time], timeZone: timezone }
        }
        body[:description] = params[:description] if params[:description].present?
        body[:location] = params[:location] if params[:location].present?

        if params[:attendees].present?
          attendees = params[:attendees].is_a?(String) ? JSON.parse(params[:attendees]) : params[:attendees]
          body[:attendees] = attendees.map { |email| { email: email } }
        end

        send_updates = params[:send_notifications] == false ? "none" : "all"
        resp = api_post("#{CALENDAR_API}/calendars/#{CGI.escape(calendar_id)}/events?sendUpdates=#{send_updates}", body)
        format_event(resp)
      end

      def update_event(params)
        calendar_id = params[:calendar_id] || "primary"
        timezone = params[:timezone] || "UTC"

        body = {}
        body[:summary] = params[:summary] if params[:summary].present?
        body[:description] = params[:description] if params[:description].present?
        body[:location] = params[:location] if params[:location].present?
        body[:start] = { dateTime: params[:start_time], timeZone: timezone } if params[:start_time].present?
        body[:end] = { dateTime: params[:end_time], timeZone: timezone } if params[:end_time].present?

        resp = api_patch("#{CALENDAR_API}/calendars/#{CGI.escape(calendar_id)}/events/#{params[:event_id]}?sendUpdates=all", body)
        format_event(resp)
      end

      def delete_event(params)
        calendar_id = params[:calendar_id] || "primary"
        resp = faraday.delete("#{CALENDAR_API}/calendars/#{CGI.escape(calendar_id)}/events/#{params[:event_id]}") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
        end
        raise Connectors::Error, "Google API error (#{resp.status}): #{resp.body}" unless resp.success?
        { deleted: true, event_id: params[:event_id] }
      end

      def list_calendars(_params)
        resp = api_get("#{CALENDAR_API}/users/me/calendarList")
        calendars = (resp["items"] || []).map do |c|
          { id: c["id"], summary: c["summary"], description: c["description"],
            primary: c["primary"], timezone: c["timeZone"], access_role: c["accessRole"] }
        end
        { calendars: calendars, count: calendars.size }
      end

      def check_availability(params)
        calendars = if params[:calendars].present?
          ids = params[:calendars].is_a?(String) ? JSON.parse(params[:calendars]) : params[:calendars]
          ids.map { |id| { id: id } }
        else
          [{ id: "primary" }]
        end

        body = {
          timeMin: params[:time_min],
          timeMax: params[:time_max],
          items: calendars
        }

        resp = api_post("#{CALENDAR_API}/freeBusy", body)
        busy_slots = (resp["calendars"] || {}).transform_values do |cal|
          (cal["busy"] || []).map { |slot| { start: slot["start"], end: slot["end"] } }
        end
        { busy: busy_slots }
      end

      def format_event(event)
        {
          id: event["id"],
          summary: event["summary"],
          description: event["description"],
          location: event["location"],
          start: event.dig("start", "dateTime") || event.dig("start", "date"),
          end: event.dig("end", "dateTime") || event.dig("end", "date"),
          timezone: event.dig("start", "timeZone"),
          status: event["status"],
          html_link: event["htmlLink"],
          attendees: (event["attendees"] || []).map { |a| { email: a["email"], status: a["responseStatus"] } },
          organizer: event.dig("organizer", "email"),
          created: event["created"],
          updated: event["updated"]
        }
      end

      def access_token
        credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token. Complete OAuth flow first.")
      end

      def api_get(url)
        resp = faraday.get(url) { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        handle_response(resp)
      end

      def api_post(url, body)
        resp = faraday.post(url) do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/json"
          r.body = body.to_json
        end
        handle_response(resp)
      end

      def api_patch(url, body)
        resp = faraday.patch(url) do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/json"
          r.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        if resp.status == 401
          raise Connectors::AuthenticationError, "Google API: token expired or revoked"
        elsif !resp.success?
          error = data.dig("error", "message") || resp.body
          raise Connectors::Error, "Google API error (#{resp.status}): #{error}"
        end
        data
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 30; f.options.open_timeout = 5 }
      end
    end
  end
end
