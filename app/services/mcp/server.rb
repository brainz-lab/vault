module Mcp
  class Server
    TOOLS = {
      "vault_list_secrets" => Tools::ListSecrets,
      "vault_get_secret" => Tools::GetSecret,
      "vault_set_secret" => Tools::SetSecret,
      "vault_delete_secret" => Tools::DeleteSecret,
      "vault_list_environments" => Tools::ListEnvironments,
      "vault_get_history" => Tools::GetHistory,
      "vault_export" => Tools::Export,
      "vault_import" => Tools::Import,
      # Credential and OTP tools
      "vault_get_credential" => Tools::GetCredential,
      "vault_set_credential" => Tools::SetCredential,
      "vault_generate_otp" => Tools::GenerateOtp,
      "vault_verify_otp" => Tools::VerifyOtp,
      # SSH Client Keys tools
      "vault_ssh_list_client_keys" => Tools::SshListClientKeys,
      "vault_ssh_get_client_key" => Tools::SshGetClientKey,
      "vault_ssh_set_client_key" => Tools::SshSetClientKey,
      "vault_ssh_delete_client_key" => Tools::SshDeleteClientKey,
      "vault_ssh_generate_key" => Tools::SshGenerateKey,
      # SSH Server Keys tools
      "vault_ssh_list_server_keys" => Tools::SshListServerKeys,
      "vault_ssh_get_server_key" => Tools::SshGetServerKey,
      "vault_ssh_set_server_key" => Tools::SshSetServerKey,
      "vault_ssh_delete_server_key" => Tools::SshDeleteServerKey,
      # SSH Connections tools
      "vault_ssh_list_connections" => Tools::SshListConnections,
      "vault_ssh_get_connection" => Tools::SshGetConnection,
      "vault_ssh_set_connection" => Tools::SshSetConnection,
      "vault_ssh_delete_connection" => Tools::SshDeleteConnection
    }.freeze

    def initialize(project:, environment: nil)
      @project = project
      @environment = environment || default_environment
    end

    def tools
      TOOLS.map do |name, tool_class|
        {
          name: name,
          description: tool_class::DESCRIPTION,
          inputSchema: tool_class::INPUT_SCHEMA
        }
      end
    end

    def call(tool_name, params = {})
      tool_class = TOOLS[tool_name]
      raise ArgumentError, "Unknown tool: #{tool_name}" unless tool_class

      tool = tool_class.new(
        project: @project,
        environment: resolve_environment(params[:environment])
      )

      tool.call(params)
    end

    def rpc(method, params = {})
      case method
      when "tools/list"
        { tools: tools }
      when "tools/call"
        tool_name = params[:name]
        tool_params = params[:arguments] || {}
        call(tool_name, tool_params)
      else
        { error: "Unknown method: #{method}" }
      end
    end

    private

    def default_environment
      @project.secret_environments.find_by(slug: "development") ||
        @project.secret_environments.first
    end

    def resolve_environment(slug)
      return @environment unless slug.present?
      @project.secret_environments.find_by(slug: slug) || @environment
    end
  end
end
