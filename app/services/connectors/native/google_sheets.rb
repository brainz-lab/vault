# frozen_string_literal: true

module Connectors
  module Native
    class GoogleSheets < Base
      def self.piece_name = "google-sheets"
      def self.display_name = "Google Sheets"
      def self.description = "Read and write data in Google Sheets spreadsheets"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/google-sheets.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent",
          tokenUrl: "https://oauth2.googleapis.com/token",
          scope: "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.readonly",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://console.cloud.google.com and create or select a project",
            "Enable the Google Sheets API and Google Drive API in APIs & Services > Library",
            "Configure the OAuth consent screen (APIs & Services > OAuth consent screen)",
            "Create OAuth credentials: APIs & Services > Credentials > Create Credentials > OAuth client ID",
            "Set Authorized redirect URI to: {VAULT_URL}/oauth/callback",
            "Copy Client ID and Client Secret",
            "Set ENV: VAULT_OAUTH_GOOGLE_SHEETS_CLIENT_ID and VAULT_OAUTH_GOOGLE_SHEETS_CLIENT_SECRET"
          ],
          docs_url: "https://developers.google.com/sheets/api/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "read_spreadsheet",
            "displayName" => "Read Spreadsheet",
            "description" => "Read data from a Google Sheets range",
            "props" => {
              "spreadsheet_id" => { "type" => "string", "required" => true, "description" => "Spreadsheet ID from the URL" },
              "range" => { "type" => "string", "required" => true, "description" => "Range in A1 notation (e.g., Sheet1!A1:D10)" }
            }
          },
          {
            "name" => "write_spreadsheet",
            "displayName" => "Write to Spreadsheet",
            "description" => "Write data to a Google Sheets range",
            "props" => {
              "spreadsheet_id" => { "type" => "string", "required" => true, "description" => "Spreadsheet ID" },
              "range" => { "type" => "string", "required" => true, "description" => "Range in A1 notation" },
              "values" => { "type" => "json", "required" => true, "description" => "2D array of values [[row1], [row2]]" }
            }
          },
          {
            "name" => "append_rows",
            "displayName" => "Append Rows",
            "description" => "Append rows to the end of a sheet",
            "props" => {
              "spreadsheet_id" => { "type" => "string", "required" => true, "description" => "Spreadsheet ID" },
              "range" => { "type" => "string", "required" => true, "description" => "Sheet name (e.g., Sheet1)" },
              "values" => { "type" => "json", "required" => true, "description" => "Rows to append [[row1], [row2]]" }
            }
          },
          {
            "name" => "list_spreadsheets",
            "displayName" => "List Spreadsheets",
            "description" => "List spreadsheets accessible to the account",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          }
        ]
      end

      SHEETS_API = "https://sheets.googleapis.com/v4/spreadsheets"
      DRIVE_API = "https://www.googleapis.com/drive/v3"

      def execute(action, **params)
        case action.to_s
        when "read_spreadsheet" then read_spreadsheet(params)
        when "write_spreadsheet" then write_spreadsheet(params)
        when "append_rows" then append_rows(params)
        when "list_spreadsheets" then list_spreadsheets(params)
        else raise Connectors::ActionNotFoundError, "Unknown Google Sheets action: #{action}"
        end
      end

      private

      def read_spreadsheet(params)
        resp = api_get("#{SHEETS_API}/#{params[:spreadsheet_id]}/values/#{params[:range]}")
        { values: resp["values"] || [], range: resp["range"] }
      end

      def write_spreadsheet(params)
        values = params[:values].is_a?(String) ? JSON.parse(params[:values]) : params[:values]
        body = { range: params[:range], majorDimension: "ROWS", values: values }

        resp = api_put(
          "#{SHEETS_API}/#{params[:spreadsheet_id]}/values/#{params[:range]}?valueInputOption=USER_ENTERED",
          body
        )
        { updated_cells: resp["updatedCells"], updated_range: resp["updatedRange"] }
      end

      def append_rows(params)
        values = params[:values].is_a?(String) ? JSON.parse(params[:values]) : params[:values]
        body = { range: params[:range], majorDimension: "ROWS", values: values }

        resp = api_post(
          "#{SHEETS_API}/#{params[:spreadsheet_id]}/values/#{params[:range]}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS",
          body
        )
        { updated_range: resp.dig("updates", "updatedRange"), updated_rows: resp.dig("updates", "updatedRows") }
      end

      def list_spreadsheets(params)
        limit = (params[:limit] || 20).to_i
        resp = api_get("#{DRIVE_API}/files?q=mimeType='application/vnd.google-apps.spreadsheet'&pageSize=#{limit}&fields=files(id,name,modifiedTime)")
        files = (resp["files"] || []).map { |f| { id: f["id"], name: f["name"], modified: f["modifiedTime"] } }
        { spreadsheets: files, count: files.size }
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

      def api_put(url, body)
        resp = faraday.put(url) do |r|
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
