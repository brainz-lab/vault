module Connectors
  module Native
    class FileStorage < Base
      SUPPORTED_PROVIDERS = %w[s3 local].freeze

      def self.piece_name = "file_storage"
      def self.display_name = "File Storage"
      def self.description = "Upload, download, list, and delete files from S3 or local storage"
      def self.category = "storage"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            provider: { type: "string", description: "s3 or local", required: false },
            bucket: { type: "string", description: "S3 bucket name", required: false },
            region: { type: "string", description: "AWS region (default: us-east-1)", required: false },
            access_key_id: { type: "string", description: "AWS access key ID", required: false },
            secret_access_key: { type: "string", description: "AWS secret access key", required: false },
            base_path: { type: "string", description: "Local storage base path", required: false }
          }
        }
      end

      def self.actions
        [
          {
            "name" => "upload",
            "displayName" => "Upload File",
            "description" => "Upload a file to storage",
            "props" => {
              "key" => { "type" => "string", "required" => true, "description" => "Storage key/path" },
              "content" => { "type" => "string", "required" => true, "description" => "File content (base64 for binary)" },
              "content_type" => { "type" => "string", "required" => false, "description" => "MIME type" }
            }
          },
          {
            "name" => "download",
            "displayName" => "Download File",
            "description" => "Download a file from storage",
            "props" => {
              "key" => { "type" => "string", "required" => true, "description" => "Storage key/path" }
            }
          },
          {
            "name" => "list",
            "displayName" => "List Files",
            "description" => "List files in storage",
            "props" => {
              "prefix" => { "type" => "string", "required" => false, "description" => "Key prefix filter" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max files (default: 100)" }
            }
          },
          {
            "name" => "delete",
            "displayName" => "Delete File",
            "description" => "Delete a file from storage",
            "props" => {
              "key" => { "type" => "string", "required" => true, "description" => "Storage key/path" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "upload" then upload(params)
        when "download" then download(params)
        when "list" then list_files(params)
        when "delete" then delete_file(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def provider
        @provider ||= begin
          p = credentials[:provider] || "local"
          unless SUPPORTED_PROVIDERS.include?(p)
            raise Connectors::Error, "Unsupported provider: #{p}. Supported: #{SUPPORTED_PROVIDERS.join(', ')}"
          end
          p
        end
      end

      def upload(params)
        provider == "s3" ? s3_upload(params) : local_upload(params)
      end

      def download(params)
        provider == "s3" ? s3_download(params) : local_download(params)
      end

      def list_files(params)
        provider == "s3" ? s3_list(params) : local_list(params)
      end

      def delete_file(params)
        provider == "s3" ? s3_delete(params) : local_delete(params)
      end

      # S3

      def s3_upload(params)
        s3_client.put_object(bucket: bucket, key: params[:key], body: params[:content], content_type: params[:content_type] || "application/octet-stream")
        { success: true, key: params[:key], bucket: bucket }
      rescue StandardError => e
        raise Connectors::Error, "S3 upload error: #{e.message}"
      end

      def s3_download(params)
        response = s3_client.get_object(bucket: bucket, key: params[:key])
        { key: params[:key], content: response.body.read, content_type: response.content_type, size: response.content_length }
      rescue StandardError => e
        raise Connectors::Error, "S3 download error: #{e.message}"
      end

      def s3_list(params)
        options = { bucket: bucket }
        options[:prefix] = params[:prefix] if params[:prefix].present?
        options[:max_keys] = (params[:limit] || 100).to_i
        response = s3_client.list_objects_v2(**options)
        files = response.contents.map { |obj| { key: obj.key, size: obj.size, last_modified: obj.last_modified.iso8601 } }
        { files: files, count: files.size, truncated: response.is_truncated }
      rescue StandardError => e
        raise Connectors::Error, "S3 list error: #{e.message}"
      end

      def s3_delete(params)
        s3_client.delete_object(bucket: bucket, key: params[:key])
        { success: true, key: params[:key] }
      rescue StandardError => e
        raise Connectors::Error, "S3 delete error: #{e.message}"
      end

      def s3_client
        @s3_client ||= begin
          require "aws-sdk-s3"
          Aws::S3::Client.new(region: credentials[:region] || "us-east-1", access_key_id: credentials[:access_key_id], secret_access_key: credentials[:secret_access_key])
        end
      end

      def bucket
        credentials[:bucket] || raise(Connectors::Error, "S3 bucket not configured")
      end

      # Local

      def local_upload(params)
        path = local_path(params[:key])
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, params[:content])
        { success: true, key: params[:key], path: path }
      end

      def local_download(params)
        path = local_path(params[:key])
        raise Connectors::Error, "File not found: #{params[:key]}" unless File.exist?(path)
        { key: params[:key], content: File.read(path), size: File.size(path) }
      end

      def local_list(params)
        pattern = File.join(local_base_path, params[:prefix] || "", "**", "*")
        limit = (params[:limit] || 100).to_i
        files = Dir.glob(pattern).select { |f| File.file?(f) }.first(limit).map do |f|
          { key: f.sub("#{local_base_path}/", ""), size: File.size(f), last_modified: File.mtime(f).iso8601 }
        end
        { files: files, count: files.size, truncated: false }
      end

      def local_delete(params)
        path = local_path(params[:key])
        raise Connectors::Error, "File not found: #{params[:key]}" unless File.exist?(path)
        File.delete(path)
        { success: true, key: params[:key] }
      end

      def local_path(key) = File.join(local_base_path, key)
      def local_base_path = credentials[:base_path] || Rails.root.join("storage", "connectors").to_s
    end
  end
end
