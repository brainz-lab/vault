module Mcp
  module Tools
    class Base
      DESCRIPTION = "Base tool"
      INPUT_SCHEMA = {
        type: "object",
        properties: {},
        required: []
      }.freeze

      def initialize(project:, environment:)
        @project = project
        @environment = environment
      end

      def call(params)
        raise NotImplementedError, "Subclass must implement #call"
      end

      protected

      attr_reader :project, :environment

      def success(data)
        { success: true, data: data }
      end

      def error(message)
        { success: false, error: message }
      end

      def log_access(action:, secret: nil, details: {})
        AuditLog.log_access(
          project: project,
          secret: secret,
          action: action,
          actor_type: "mcp",
          actor_id: "mcp-tool",
          actor_name: "MCP Client",
          ip_address: nil,
          user_agent: "MCP",
          details: details
        )
      end
    end
  end
end
