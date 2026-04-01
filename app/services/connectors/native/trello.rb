# frozen_string_literal: true

module Connectors
  module Native
    class Trello < Base
      def self.piece_name = "trello"
      def self.display_name = "Trello"
      def self.description = "Manage boards, lists, and cards in Trello"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/trello.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            api_key: { type: "string", description: "Trello API Key (https://trello.com/power-ups/admin)", required: true },
            token: { type: "string", description: "Trello Token (generated after authorizing your key)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://trello.com/power-ups/admin → New → generate API Key",
            "Copy the API Key",
            "Click 'generate a Token' link next to the key → Authorize",
            "Copy the generated token"
          ],
          docs_url: "https://developer.atlassian.com/cloud/trello/guides/rest-api/api-introduction/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_boards",
            "displayName" => "List Boards",
            "description" => "List all boards for the authenticated user",
            "props" => {
              "filter" => { "type" => "string", "required" => false, "description" => "Filter: open, closed, all (default: open)" }
            }
          },
          {
            "name" => "list_lists",
            "displayName" => "List Lists",
            "description" => "List all lists on a board",
            "props" => {
              "board_id" => { "type" => "string", "required" => true, "description" => "Board ID" },
              "filter" => { "type" => "string", "required" => false, "description" => "Filter: open, closed, all (default: open)" }
            }
          },
          {
            "name" => "list_cards",
            "displayName" => "List Cards",
            "description" => "List cards on a board or list",
            "props" => {
              "board_id" => { "type" => "string", "required" => false, "description" => "Board ID (list all cards)" },
              "list_id" => { "type" => "string", "required" => false, "description" => "List ID (cards in specific list)" },
              "filter" => { "type" => "string", "required" => false, "description" => "Filter: open, closed, all (default: open)" }
            }
          },
          {
            "name" => "create_card",
            "displayName" => "Create Card",
            "description" => "Create a new card",
            "props" => {
              "list_id" => { "type" => "string", "required" => true, "description" => "List ID to create card in" },
              "name" => { "type" => "string", "required" => true, "description" => "Card name" },
              "desc" => { "type" => "string", "required" => false, "description" => "Card description (Markdown)" },
              "due" => { "type" => "string", "required" => false, "description" => "Due date (ISO 8601)" },
              "labels" => { "type" => "string", "required" => false, "description" => "Comma-separated label IDs" },
              "members" => { "type" => "string", "required" => false, "description" => "Comma-separated member IDs" },
              "pos" => { "type" => "string", "required" => false, "description" => "Position: top or bottom (default: bottom)" }
            }
          },
          {
            "name" => "update_card",
            "displayName" => "Update Card",
            "description" => "Update a card",
            "props" => {
              "card_id" => { "type" => "string", "required" => true, "description" => "Card ID" },
              "name" => { "type" => "string", "required" => false, "description" => "New name" },
              "desc" => { "type" => "string", "required" => false, "description" => "New description" },
              "due" => { "type" => "string", "required" => false, "description" => "New due date (ISO 8601, empty to clear)" },
              "closed" => { "type" => "boolean", "required" => false, "description" => "Archive card" },
              "list_id" => { "type" => "string", "required" => false, "description" => "Move to list ID" }
            }
          },
          {
            "name" => "add_comment",
            "displayName" => "Add Comment",
            "description" => "Add a comment to a card",
            "props" => {
              "card_id" => { "type" => "string", "required" => true, "description" => "Card ID" },
              "text" => { "type" => "string", "required" => true, "description" => "Comment text" }
            }
          },
          {
            "name" => "move_card",
            "displayName" => "Move Card",
            "description" => "Move a card to a different list",
            "props" => {
              "card_id" => { "type" => "string", "required" => true, "description" => "Card ID" },
              "list_id" => { "type" => "string", "required" => true, "description" => "Destination list ID" },
              "pos" => { "type" => "string", "required" => false, "description" => "Position: top or bottom" }
            }
          }
        ]
      end

      API_BASE = "https://api.trello.com/1"

      def execute(action, **params)
        case action.to_s
        when "list_boards" then list_boards(params)
        when "list_lists" then list_lists(params)
        when "list_cards" then list_cards(params)
        when "create_card" then create_card(params)
        when "update_card" then update_card(params)
        when "add_comment" then add_comment(params)
        when "move_card" then move_card(params)
        else raise Connectors::ActionNotFoundError, "Unknown Trello action: #{action}"
        end
      end

      private

      def list_boards(params)
        query = { filter: params[:filter] || "open", fields: "name,closed,url,dateLastActivity" }
        result = api_get("members/me/boards", query)
        boards = result.map do |b|
          { id: b["id"], name: b["name"], closed: b["closed"], url: b["url"],
            last_activity: b["dateLastActivity"] }
        end
        { boards: boards, count: boards.size }
      end

      def list_lists(params)
        query = { filter: params[:filter] || "open", fields: "name,closed,pos" }
        result = api_get("boards/#{params[:board_id]}/lists", query)
        lists = result.map { |l| { id: l["id"], name: l["name"], closed: l["closed"], pos: l["pos"] } }
        { lists: lists, count: lists.size }
      end

      def list_cards(params)
        filter = params[:filter] || "open"
        fields = "name,desc,due,closed,labels,idMembers,idList,shortUrl,dateLastActivity"

        path = if params[:list_id].present?
                 "lists/#{params[:list_id]}/cards"
        elsif params[:board_id].present?
                 "boards/#{params[:board_id]}/cards/#{filter}"
        else
                 raise Connectors::Error, "Either board_id or list_id is required"
        end

        result = api_get(path, fields: fields)
        cards = result.map do |c|
          { id: c["id"], name: c["name"], desc: c["desc"]&.truncate(200),
            due: c["due"], closed: c["closed"], list_id: c["idList"],
            labels: c["labels"]&.map { |l| l["name"] }, url: c["shortUrl"] }
        end
        { cards: cards, count: cards.size }
      end

      def create_card(params)
        body = { idList: params[:list_id], name: params[:name] }
        body[:desc] = params[:desc] if params[:desc].present?
        body[:due] = params[:due] if params[:due].present?
        body[:idLabels] = params[:labels] if params[:labels].present?
        body[:idMembers] = params[:members] if params[:members].present?
        body[:pos] = params[:pos] if params[:pos].present?

        result = api_post("cards", body)
        { success: true, id: result["id"], name: result["name"], url: result["shortUrl"] }
      end

      def update_card(params)
        body = {}
        body[:name] = params[:name] if params[:name].present?
        body[:desc] = params[:desc] if params.key?(:desc)
        body[:due] = params[:due] if params.key?(:due)
        body[:closed] = params[:closed] if params.key?(:closed)
        body[:idList] = params[:list_id] if params[:list_id].present?

        result = api_put("cards/#{params[:card_id]}", body)
        { success: true, id: result["id"], name: result["name"] }
      end

      def add_comment(params)
        result = api_post("cards/#{params[:card_id]}/actions/comments", { text: params[:text] })
        { success: true, id: result["id"] }
      end

      def move_card(params)
        body = { idList: params[:list_id] }
        body[:pos] = params[:pos] if params[:pos].present?

        result = api_put("cards/#{params[:card_id]}", body)
        { success: true, id: result["id"], name: result["name"], list_id: result["idList"] }
      end

      # NOTE: Trello's API requires key/token as query params (no Authorization header support).
      # Ensure Rails.application.config.filter_parameters includes :token and :key to prevent log leakage.
      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.params = params.merge(key: api_key, token: token)
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API_BASE}/#{path}") do |req|
          req.params = { key: api_key, token: token }
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{API_BASE}/#{path}") do |req|
          req.params = { key: api_key, token: token }
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data.is_a?(String) ? data : (data["message"] || "HTTP #{resp.status}")
          raise Connectors::AuthenticationError, "Trello: #{error}" if resp.status == 401
          raise Connectors::RateLimitError, "Trello rate limited" if resp.status == 429
          raise Connectors::Error, "Trello API error: #{error}"
        end
        data
      end

      def api_key = credentials[:api_key]
      def token = credentials[:token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
