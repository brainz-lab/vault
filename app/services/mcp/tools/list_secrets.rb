module Mcp
  module Tools
    class ListSecrets < Base
      DESCRIPTION = "List all secret names in the vault. Returns only names, not values."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          folder: {
            type: "string",
            description: "Optional folder path to filter secrets"
          },
          tag: {
            type: "string",
            description: "Optional tag filter in format 'key:value'"
          }
        },
        required: []
      }.freeze

      def call(params)
        secrets = project.secrets.active

        if params[:folder].present?
          folder = project.secret_folders.find_by(path: params[:folder])
          secrets = secrets.in_folder(folder) if folder
        end

        if params[:tag].present?
          key, value = params[:tag].split(":")
          secrets = secrets.with_tag(key, value)
        end

        log_access(action: "mcp_list_secrets", details: { count: secrets.count })

        success(
          secrets: secrets.map { |s| { key: s.key, path: s.path, description: s.description } },
          count: secrets.count,
          environment: environment.slug
        )
      end
    end
  end
end
