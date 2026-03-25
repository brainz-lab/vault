# frozen_string_literal: true

module Connectors
  module Native
    class GoogleDrive < Base
      def self.piece_name = "google-drive"
      def self.display_name = "Google Drive"
      def self.description = "Manage files and folders in Google Drive"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/google-drive.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent",
          tokenUrl: "https://oauth2.googleapis.com/token",
          scope: "https://www.googleapis.com/auth/drive",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://console.cloud.google.com and create or select a project",
            "Enable the Google Drive API in APIs & Services > Library",
            "Configure the OAuth consent screen (APIs & Services > OAuth consent screen)",
            "Create OAuth credentials: APIs & Services > Credentials > Create Credentials > OAuth client ID",
            "Set Authorized redirect URI to: {VAULT_URL}/oauth/callback",
            "Copy Client ID and Client Secret",
            "Set ENV: VAULT_OAUTH_GOOGLE_DRIVE_CLIENT_ID and VAULT_OAUTH_GOOGLE_DRIVE_CLIENT_SECRET"
          ],
          docs_url: "https://developers.google.com/drive/api/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "list_files",
            "displayName" => "List Files",
            "description" => "List files and folders in Google Drive",
            "props" => {
              "query" => { "type" => "string", "required" => false, "description" => "Search query (Drive search syntax, e.g. name contains 'report')" },
              "folder_id" => { "type" => "string", "required" => false, "description" => "Folder ID to list contents of (default: root)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "get_file",
            "displayName" => "Get File Metadata",
            "description" => "Get metadata for a specific file",
            "props" => {
              "file_id" => { "type" => "string", "required" => true, "description" => "File ID" }
            }
          },
          {
            "name" => "download_file",
            "displayName" => "Download File Content",
            "description" => "Download file content (text-based files only)",
            "props" => {
              "file_id" => { "type" => "string", "required" => true, "description" => "File ID" },
              "mime_type" => { "type" => "string", "required" => false, "description" => "Export MIME type for Google Docs (e.g. text/plain, application/pdf)" }
            }
          },
          {
            "name" => "create_folder",
            "displayName" => "Create Folder",
            "description" => "Create a new folder in Google Drive",
            "props" => {
              "name" => { "type" => "string", "required" => true, "description" => "Folder name" },
              "parent_id" => { "type" => "string", "required" => false, "description" => "Parent folder ID (default: root)" }
            }
          },
          {
            "name" => "upload_file",
            "displayName" => "Upload File",
            "description" => "Upload a text file to Google Drive",
            "props" => {
              "name" => { "type" => "string", "required" => true, "description" => "File name" },
              "content" => { "type" => "string", "required" => true, "description" => "File content (text)" },
              "mime_type" => { "type" => "string", "required" => false, "description" => "MIME type (default: text/plain)" },
              "folder_id" => { "type" => "string", "required" => false, "description" => "Parent folder ID" }
            }
          },
          {
            "name" => "share_file",
            "displayName" => "Share File",
            "description" => "Share a file or folder with a user",
            "props" => {
              "file_id" => { "type" => "string", "required" => true, "description" => "File or folder ID" },
              "email" => { "type" => "string", "required" => true, "description" => "Email address to share with" },
              "role" => { "type" => "string", "required" => false, "description" => "Permission role: reader, writer, commenter (default: reader)" }
            }
          },
          {
            "name" => "delete_file",
            "displayName" => "Delete File",
            "description" => "Move a file or folder to trash",
            "props" => {
              "file_id" => { "type" => "string", "required" => true, "description" => "File or folder ID" }
            }
          }
        ]
      end

      DRIVE_API = "https://www.googleapis.com/drive/v3"
      UPLOAD_API = "https://www.googleapis.com/upload/drive/v3"

      def execute(action, **params)
        case action.to_s
        when "list_files" then list_files(params)
        when "get_file" then get_file(params)
        when "download_file" then download_file(params)
        when "create_folder" then create_folder(params)
        when "upload_file" then upload_file(params)
        when "share_file" then share_file(params)
        when "delete_file" then delete_file(params)
        else raise Connectors::ActionNotFoundError, "Unknown Google Drive action: #{action}"
        end
      end

      private

      def list_files(params)
        limit = (params[:limit] || 20).to_i
        query_parts = []
        query_parts << "'#{params[:folder_id]}' in parents" if params[:folder_id].present?
        query_parts << params[:query] if params[:query].present?
        query_parts << "trashed = false"

        q = query_parts.join(" and ")
        url = "#{DRIVE_API}/files?q=#{CGI.escape(q)}&pageSize=#{limit}&fields=files(id,name,mimeType,size,modifiedTime,parents,webViewLink)"

        resp = api_get(url)
        files = (resp["files"] || []).map do |f|
          { id: f["id"], name: f["name"], mime_type: f["mimeType"], size: f["size"],
            modified: f["modifiedTime"], parents: f["parents"], url: f["webViewLink"] }
        end
        { files: files, count: files.size }
      end

      def get_file(params)
        resp = api_get("#{DRIVE_API}/files/#{params[:file_id]}?fields=id,name,mimeType,size,modifiedTime,createdTime,parents,webViewLink,owners,shared")
        { id: resp["id"], name: resp["name"], mime_type: resp["mimeType"], size: resp["size"],
          modified: resp["modifiedTime"], created: resp["createdTime"], parents: resp["parents"],
          url: resp["webViewLink"], owners: resp["owners"], shared: resp["shared"] }
      end

      def download_file(params)
        if params[:mime_type].present?
          url = "#{DRIVE_API}/files/#{params[:file_id]}/export?mimeType=#{CGI.escape(params[:mime_type])}"
        else
          url = "#{DRIVE_API}/files/#{params[:file_id]}?alt=media"
        end

        resp = faraday.get(url) { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        raise Connectors::Error, "Google API error (#{resp.status}): #{resp.body}" unless resp.success?

        { content: resp.body, file_id: params[:file_id] }
      end

      def create_folder(params)
        body = {
          name: params[:name],
          mimeType: "application/vnd.google-apps.folder"
        }
        body[:parents] = [params[:parent_id]] if params[:parent_id].present?

        resp = api_post("#{DRIVE_API}/files", body)
        { id: resp["id"], name: resp["name"] }
      end

      def upload_file(params)
        mime_type = params[:mime_type] || "text/plain"
        metadata = { name: params[:name], mimeType: mime_type }
        metadata[:parents] = [params[:folder_id]] if params[:folder_id].present?

        boundary = SecureRandom.hex(16)
        body = build_multipart_body(boundary, metadata, params[:content], mime_type)

        resp = faraday.post("#{UPLOAD_API}/files?uploadType=multipart") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "multipart/related; boundary=#{boundary}"
          r.body = body
        end
        handle_response(resp)

        { id: resp.body.is_a?(String) ? JSON.parse(resp.body)["id"] : resp.body["id"], name: params[:name] }
      end

      def share_file(params)
        role = params[:role] || "reader"
        body = { role: role, type: "user", emailAddress: params[:email] }
        resp = api_post("#{DRIVE_API}/files/#{params[:file_id]}/permissions?sendNotificationEmail=true", body)
        { permission_id: resp["id"], role: role, email: params[:email] }
      end

      def delete_file(params)
        resp = faraday.patch("#{DRIVE_API}/files/#{params[:file_id]}") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/json"
          r.body = { trashed: true }.to_json
        end
        handle_response(resp)
        { trashed: true, file_id: params[:file_id] }
      end

      def build_multipart_body(boundary, metadata, content, mime_type)
        body = ""
        body << "--#{boundary}\r\n"
        body << "Content-Type: application/json; charset=UTF-8\r\n\r\n"
        body << metadata.to_json
        body << "\r\n--#{boundary}\r\n"
        body << "Content-Type: #{mime_type}\r\n\r\n"
        body << content
        body << "\r\n--#{boundary}--"
        body
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

      def handle_response(resp)
        data = resp.body.is_a?(String) ? JSON.parse(resp.body) : resp.body
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
