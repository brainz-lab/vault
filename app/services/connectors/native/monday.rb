# frozen_string_literal: true

module Connectors
  module Native
    class Monday < Base
      def self.piece_name = "monday"
      def self.display_name = "Monday.com"
      def self.description = "Manage boards, items, and updates in Monday.com"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/monday.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_token: { type: "string", description: "Monday.com API Token (Avatar → Developers → My Access Tokens)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Log in to Monday.com → click your avatar → Developers",
            "Go to 'My Access Tokens' → 'Show' or generate a new token",
            "Copy the API token"
          ],
          docs_url: "https://developer.monday.com/api-reference/docs/authentication"
        }
      end

      def self.actions
        [
          {
            "name" => "list_boards",
            "displayName" => "List Boards",
            "description" => "List all accessible boards",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max boards (default: 25)" }
            }
          },
          {
            "name" => "list_items",
            "displayName" => "List Items",
            "description" => "List items in a board",
            "props" => {
              "board_id" => { "type" => "string", "required" => true, "description" => "Board ID" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max items (default: 50)" }
            }
          },
          {
            "name" => "create_item",
            "displayName" => "Create Item",
            "description" => "Create a new item in a board",
            "props" => {
              "board_id" => { "type" => "string", "required" => true, "description" => "Board ID" },
              "item_name" => { "type" => "string", "required" => true, "description" => "Item name" },
              "group_id" => { "type" => "string", "required" => false, "description" => "Group ID (uses first group if omitted)" },
              "column_values" => { "type" => "json", "required" => false, "description" => "Column values as JSON object" }
            }
          },
          {
            "name" => "update_item",
            "displayName" => "Update Item",
            "description" => "Update column values of an item",
            "props" => {
              "board_id" => { "type" => "string", "required" => true, "description" => "Board ID" },
              "item_id" => { "type" => "string", "required" => true, "description" => "Item ID" },
              "column_values" => { "type" => "json", "required" => true, "description" => "Column values to update (JSON object)" }
            }
          },
          {
            "name" => "add_update",
            "displayName" => "Add Update",
            "description" => "Add a text update (comment) to an item",
            "props" => {
              "item_id" => { "type" => "string", "required" => true, "description" => "Item ID" },
              "body" => { "type" => "string", "required" => true, "description" => "Update body (HTML supported)" }
            }
          },
          {
            "name" => "list_groups",
            "displayName" => "List Groups",
            "description" => "List groups in a board",
            "props" => {
              "board_id" => { "type" => "string", "required" => true, "description" => "Board ID" }
            }
          }
        ]
      end

      API_URL = "https://api.monday.com/v2"

      def execute(action, **params)
        case action.to_s
        when "list_boards" then list_boards(params)
        when "list_items" then list_items(params)
        when "create_item" then create_item(params)
        when "update_item" then update_item(params)
        when "add_update" then add_update(params)
        when "list_groups" then list_groups(params)
        else raise Connectors::ActionNotFoundError, "Unknown Monday.com action: #{action}"
        end
      end

      private

      def list_boards(params)
        limit = (params[:limit] || 25).to_i
        result = graphql(
          "query($limit: Int!) { boards(limit: $limit) { id name state board_kind columns { id title type } } }",
          variables: { limit: limit }
        )
        boards = (result.dig("data", "boards") || []).map do |b|
          { id: b["id"], name: b["name"], state: b["state"], kind: b["board_kind"],
            columns: b["columns"]&.map { |c| { id: c["id"], title: c["title"], type: c["type"] } } }
        end
        { boards: boards, count: boards.size }
      end

      def list_items(params)
        limit = (params[:limit] || 50).to_i
        board_id = params[:board_id].to_i
        result = graphql(
          "query($boardId: [ID!]!, $limit: Int!) { boards(ids: $boardId) { items_page(limit: $limit) { items { id name group { id title } column_values { id text value } created_at updated_at } } } }",
          variables: { boardId: [board_id], limit: limit }
        )
        items = result.dig("data", "boards", 0, "items_page", "items") || []
        items = items.map do |i|
          columns = (i["column_values"] || []).to_h { |c| [c["id"], c["text"]] }
          { id: i["id"], name: i["name"], group: i.dig("group", "title"),
            columns: columns, created_at: i["created_at"] }
        end
        { items: items, count: items.size }
      end

      def create_item(params)
        col_values = params[:column_values]
        col_values = col_values.to_json if col_values.is_a?(Hash)
        col_values = col_values || "{}"

        vars = { boardId: params[:board_id].to_i, itemName: params[:item_name].to_s, columnValues: col_values }
        vars[:groupId] = params[:group_id].to_s if params[:group_id].present?

        group_param = params[:group_id].present? ? ", $groupId: String" : ""
        group_arg = params[:group_id].present? ? ", group_id: $groupId" : ""

        result = graphql(
          "mutation($boardId: ID!, $itemName: String!, $columnValues: JSON!#{group_param}) { create_item(board_id: $boardId, item_name: $itemName, column_values: $columnValues#{group_arg}) { id name } }",
          variables: vars
        )
        item = result.dig("data", "create_item")
        { success: true, id: item["id"], name: item["name"] }
      end

      def update_item(params)
        col_values = params[:column_values]
        col_values = col_values.to_json if col_values.is_a?(Hash)

        result = graphql(
          "mutation($boardId: ID!, $itemId: ID!, $columnValues: JSON!) { change_multiple_column_values(board_id: $boardId, item_id: $itemId, column_values: $columnValues) { id name } }",
          variables: { boardId: params[:board_id].to_i, itemId: params[:item_id].to_i, columnValues: col_values }
        )
        item = result.dig("data", "change_multiple_column_values")
        { success: true, id: item["id"], name: item["name"] }
      end

      def add_update(params)
        result = graphql(
          "mutation($itemId: ID!, $body: String!) { create_update(item_id: $itemId, body: $body) { id } }",
          variables: { itemId: params[:item_id].to_i, body: params[:body].to_s }
        )
        { success: true, update_id: result.dig("data", "create_update", "id") }
      end

      def list_groups(params)
        board_id = params[:board_id].to_i
        result = graphql(
          "query($boardId: [ID!]!) { boards(ids: $boardId) { groups { id title color position } } }",
          variables: { boardId: [board_id] }
        )
        groups = result.dig("data", "boards", 0, "groups") || []
        groups = groups.map { |g| { id: g["id"], title: g["title"], color: g["color"] } }
        { groups: groups, count: groups.size }
      end

      def graphql(query, variables: {})
        resp = faraday.post(API_URL) do |req|
          req.headers["Authorization"] = api_token
          req.headers["Content-Type"] = "application/json"
          req.headers["API-Version"] = "2024-01"
          req.body = { query: query, variables: variables }.to_json
        end

        data = JSON.parse(resp.body)

        if data["errors"].present?
          error = data["errors"].map { |e| e["message"] }.join(", ")
          raise Connectors::AuthenticationError, "Monday.com: #{error}" if error.include?("Not Authenticated")
          raise Connectors::RateLimitError, "Monday.com: #{error}" if error.include?("Rate limit")
          raise Connectors::Error, "Monday.com API error: #{error}"
        end

        unless resp.success?
          raise Connectors::Error, "Monday.com HTTP #{resp.status}"
        end

        data
      end

      def escape_gql(str)
        str.to_s.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("\n", '\\n')
      end

      def api_token = credentials[:api_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
