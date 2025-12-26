module Mcp
  module Tools
    class Export < Base
      DESCRIPTION = "Export all secrets for an environment in various formats."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          environment: {
            type: "string",
            description: "Environment slug (defaults to development)"
          },
          format: {
            type: "string",
            enum: ["json", "dotenv", "shell", "yaml"],
            description: "Output format (default: json)"
          },
          service: {
            type: "string",
            description: "Optional service name to filter secrets by tag"
          }
        },
        required: []
      }.freeze

      def call(params)
        format = (params[:format] || "json").to_sym
        service = params[:service]

        resolver = SecretResolver.new(project, environment)

        secrets = if service.present?
          resolver.resolve_for_service(service)
        else
          resolver.resolve_all
        end

        log_access(
          action: "mcp_export",
          details: {
            environment: environment.slug,
            format: format,
            count: secrets.count
          }
        )

        output = case format
        when :dotenv
          secrets.map { |k, v| "#{k}=#{escape_value(v)}" }.join("\n")
        when :shell
          secrets.map { |k, v| "export #{k}=#{Shellwords.escape(v)}" }.join("\n")
        when :yaml
          secrets.to_yaml
        else
          secrets
        end

        success(
          environment: environment.slug,
          format: format,
          count: secrets.count,
          output: output
        )
      end

      private

      def escape_value(value)
        return '""' if value.nil? || value.empty?

        if value.match?(/[\s#"'$\\]/) || value.include?("\n")
          escaped = value.gsub('\\', '\\\\').gsub('"', '\\"').gsub("\n", '\\n')
          "\"#{escaped}\""
        else
          value
        end
      end
    end
  end
end
