# frozen_string_literal: true

module Connectors
  module Native
    class Mailchimp < Base
      def self.piece_name = "mailchimp"
      def self.display_name = "Mailchimp"
      def self.description = "Manage email campaigns, audiences, and subscribers in Mailchimp"
      def self.category = "marketing"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/mailchimp.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_key: { type: "string", description: "Mailchimp API Key (Account → Extras → API keys)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Log in to Mailchimp → Account → Extras → API keys",
            "Click 'Create A Key' and copy the full key",
            "The datacenter is the suffix after the dash (e.g., us21)"
          ],
          docs_url: "https://mailchimp.com/developer/marketing/guides/quick-start/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_audiences",
            "displayName" => "List Audiences",
            "description" => "List all audiences (lists)",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "list_members",
            "displayName" => "List Members",
            "description" => "List members of an audience",
            "props" => {
              "list_id" => { "type" => "string", "required" => true, "description" => "Audience/List ID" },
              "status" => { "type" => "string", "required" => false, "description" => "Filter: subscribed, unsubscribed, cleaned, pending, transactional" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "add_member",
            "displayName" => "Add/Update Member",
            "description" => "Add or update a subscriber in an audience",
            "props" => {
              "list_id" => { "type" => "string", "required" => true, "description" => "Audience/List ID" },
              "email" => { "type" => "string", "required" => true, "description" => "Email address" },
              "status" => { "type" => "string", "required" => false, "description" => "Status: subscribed, pending (default: subscribed)" },
              "first_name" => { "type" => "string", "required" => false, "description" => "First name" },
              "last_name" => { "type" => "string", "required" => false, "description" => "Last name" },
              "tags" => { "type" => "string", "required" => false, "description" => "Comma-separated tags" }
            }
          },
          {
            "name" => "list_campaigns",
            "displayName" => "List Campaigns",
            "description" => "List email campaigns",
            "props" => {
              "status" => { "type" => "string", "required" => false, "description" => "Filter: save, paused, schedule, sending, sent" },
              "type" => { "type" => "string", "required" => false, "description" => "Filter: regular, plaintext, absplit, rss, variate" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "get_campaign_report",
            "displayName" => "Get Campaign Report",
            "description" => "Get performance report for a sent campaign",
            "props" => {
              "campaign_id" => { "type" => "string", "required" => true, "description" => "Campaign ID" }
            }
          },
          {
            "name" => "search_members",
            "displayName" => "Search Members",
            "description" => "Search for members across all audiences",
            "props" => {
              "query" => { "type" => "string", "required" => true, "description" => "Search query (email or name)" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_audiences" then list_audiences(params)
        when "list_members" then list_members(params)
        when "add_member" then add_member(params)
        when "list_campaigns" then list_campaigns(params)
        when "get_campaign_report" then get_campaign_report(params)
        when "search_members" then search_members(params)
        else raise Connectors::ActionNotFoundError, "Unknown Mailchimp action: #{action}"
        end
      end

      private

      def list_audiences(params)
        result = api_get("lists", count: (params[:limit] || 25).to_i)
        lists = (result["lists"] || []).map do |l|
          { id: l["id"], name: l["name"], member_count: l.dig("stats", "member_count"),
            unsubscribe_count: l.dig("stats", "unsubscribe_count"), campaign_count: l.dig("stats", "campaign_count") }
        end
        { audiences: lists, count: lists.size }
      end

      def list_members(params)
        query = { count: (params[:limit] || 50).to_i }
        query[:status] = params[:status] if params[:status].present?

        result = api_get("lists/#{params[:list_id]}/members", query)
        members = (result["members"] || []).map do |m|
          { id: m["id"], email: m["email_address"], status: m["status"],
            first_name: m.dig("merge_fields", "FNAME"), last_name: m.dig("merge_fields", "LNAME"),
            tags: m["tags"]&.map { |t| t["name"] } }
        end
        { members: members, count: members.size, total: result["total_items"] }
      end

      def add_member(params)
        email_hash = Digest::MD5.hexdigest(params[:email].downcase)
        body = {
          email_address: params[:email],
          status_if_new: params[:status] || "subscribed"
        }

        merge_fields = {}
        merge_fields["FNAME"] = params[:first_name] if params[:first_name].present?
        merge_fields["LNAME"] = params[:last_name] if params[:last_name].present?
        body[:merge_fields] = merge_fields if merge_fields.any?

        if params[:tags].present?
          body[:tags] = params[:tags].split(",").map(&:strip)
        end

        result = api_put("lists/#{params[:list_id]}/members/#{email_hash}", body)
        { success: true, id: result["id"], email: result["email_address"], status: result["status"] }
      end

      def list_campaigns(params)
        query = { count: (params[:limit] || 25).to_i }
        query[:status] = params[:status] if params[:status].present?
        query[:type] = params[:type] if params[:type].present?

        result = api_get("campaigns", query)
        campaigns = (result["campaigns"] || []).map do |c|
          { id: c["id"], type: c["type"], status: c["status"],
            subject: c.dig("settings", "subject_line"), title: c.dig("settings", "title"),
            emails_sent: c["emails_sent"], send_time: c["send_time"] }
        end
        { campaigns: campaigns, count: campaigns.size }
      end

      def get_campaign_report(params)
        result = api_get("reports/#{params[:campaign_id]}")
        {
          id: result["id"], campaign_title: result["campaign_title"],
          subject_line: result["subject_line"], emails_sent: result["emails_sent"],
          opens: result.dig("opens", "opens_total"), unique_opens: result.dig("opens", "unique_opens"),
          open_rate: result.dig("opens", "open_rate"),
          clicks: result.dig("clicks", "clicks_total"), unique_clicks: result.dig("clicks", "unique_clicks"),
          click_rate: result.dig("clicks", "click_rate"),
          unsubscribed: result["unsubscribed"], bounces: result.dig("bounces", "hard_bounces")
        }
      end

      def search_members(params)
        result = api_get("search-members", query: params[:query])
        members = (result.dig("exact_matches", "members") || []).map do |m|
          { id: m["id"], email: m["email_address"], status: m["status"], list_id: m["list_id"],
            first_name: m.dig("merge_fields", "FNAME"), last_name: m.dig("merge_fields", "LNAME") }
        end
        { members: members, count: members.size }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.params = params
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data["detail"] || data["title"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Mailchimp: #{error}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Mailchimp rate limited" if resp.status == 429
          raise Connectors::Error, "Mailchimp API error: #{error}"
        end
        data
      end

      def api_base
        dc = api_key.split("-").last
        "https://#{dc}.api.mailchimp.com/3.0"
      end

      def api_key = credentials[:api_key]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
