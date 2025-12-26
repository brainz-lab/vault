module Mcp
  module Tools
    class Import < Base
      DESCRIPTION = "Import secrets from .env or JSON format."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          content: {
            type: "string",
            description: "The content to import (env file or JSON)"
          },
          format: {
            type: "string",
            enum: ["dotenv", "json"],
            description: "Input format (default: dotenv)"
          },
          environment: {
            type: "string",
            description: "Target environment slug (defaults to development)"
          }
        },
        required: ["content"]
      }.freeze

      def call(params)
        content = params[:content]
        format = (params[:format] || "dotenv").to_sym

        return error("content is required") unless content.present?

        importer = SecretImporter.new(project, environment)

        result = case format
        when :json
          importer.import_from_json(content)
        else
          importer.import_from_env_file(content)
        end

        log_access(
          action: "mcp_import",
          details: {
            environment: environment.slug,
            format: format,
            imported: result[:imported].count,
            errors: result[:errors].count
          }
        )

        success(
          environment: environment.slug,
          imported: result[:imported],
          errors: result[:errors]
        )
      end
    end
  end
end
