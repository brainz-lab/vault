module Connectors
  class Executor
    def initialize(project:, caller_service: nil, caller_request_id: nil)
      @project = project
      @caller_service = caller_service
      @caller_request_id = caller_request_id
    end

    def execute(connection_id:, action_name:, input: {}, timeout: 30_000)
      connection = @project.connector_connections.connected.find(connection_id)
      connector = connection.connector

      action = connector.find_action(action_name)
      raise ActionNotFoundError, "Action '#{action_name}' not found for connector '#{connector.piece_name}'" unless action

      credentials = decrypt_credentials(connection)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = route_execution(connector, action_name, input, credentials, timeout)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      connection.record_execution!
      connection.connector_credential&.mark_used!

      ConnectorExecution.record(
        project: @project,
        connection: connection,
        action_name: action_name,
        status: "success",
        duration_ms: duration_ms,
        input_hash: Digest::SHA256.hexdigest(input.to_json),
        output_summary: truncate_output(result),
        caller_service: @caller_service,
        caller_request_id: @caller_request_id
      )

      { success: true, output: result, duration_ms: duration_ms }
    rescue Connectors::Error => e
      record_failure(connection, action_name, input, e, start_time)
      raise
    rescue ActiveRecord::RecordNotFound
      raise NotConnectedError, "Connection not found or not active"
    rescue StandardError => e
      record_failure(connection, action_name, input, e, start_time)
      raise Connectors::Error, e.message
    end

    private

    def route_execution(connector, action_name, input, credentials, timeout)
      case connector.connector_type
      when "activepieces"
        execute_activepieces(connector, action_name, input, credentials, timeout)
      when "native"
        execute_native(connector, action_name, input, credentials)
      else
        raise Connectors::Error, "Unsupported connector type: #{connector.connector_type}"
      end
    end

    def execute_activepieces(connector, action_name, input, credentials, timeout)
      sidecar_url = ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
      sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]

      response = Faraday.new(url: sidecar_url) do |f|
        f.request :json
        f.response :json
        f.options.timeout = (timeout / 1000.0).ceil + 5
        f.options.open_timeout = 10
      end.post("/execute") do |req|
        req.headers["Authorization"] = "Bearer #{sidecar_key}" if sidecar_key.present?
        req.body = {
          piece: connector.piece_name,
          action: action_name,
          input: input,
          auth: credentials,
          timeout: timeout
        }
      end

      body = response.body
      if response.success? && body["success"]
        body["output"]
      else
        raise Connectors::Error, body["error"] || "Sidecar execution failed (HTTP #{response.status})"
      end
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise SidecarUnavailableError, "Connector sidecar unavailable: #{e.message}"
    end

    def execute_native(connector, action_name, input, credentials)
      runner_class = native_runner_for(connector.piece_name)
      runner = runner_class.new(credentials)
      runner.execute(action_name, **input.symbolize_keys)
    end

    def native_runner_for(piece_name)
      case piece_name
      when "webhook" then Connectors::Native::Webhook
      when "database" then Connectors::Native::Database
      when "email" then Connectors::Native::Email
      when "file_storage" then Connectors::Native::FileStorage
      when "apollo" then Connectors::Native::Apollo
      when "bitrix" then Connectors::Native::Bitrix
      when "kommo" then Connectors::Native::Kommo
      when "slack" then Connectors::Native::Slack
      when "slack-oauth" then Connectors::Native::SlackOauth
      when "github" then Connectors::Native::GithubOauth
      when "google-sheets" then Connectors::Native::GoogleSheets
      when "google-drive" then Connectors::Native::GoogleDrive
      when "google-calendar" then Connectors::Native::GoogleCalendar
      when "gmail" then Connectors::Native::Gmail
      when "hubspot" then Connectors::Native::Hubspot
      when "microsoft-outlook" then Connectors::Native::MicrosoftOutlook
      when "notion" then Connectors::Native::Notion
      when "jira-cloud" then Connectors::Native::JiraCloud
      when "airtable" then Connectors::Native::Airtable
      when "stripe" then Connectors::Native::StripeConnect
      when "whatsapp" then Connectors::Native::Whatsapp
      when "salesforce" then Connectors::Native::Salesforce
      else
        raise Connectors::Error, "Unknown native connector: #{piece_name}"
      end
    end

    def decrypt_credentials(connection)
      credential = connection.connector_credential
      return {} unless credential

      if credential.oauth?
        begin
          credential.active_or_refresh!
        rescue Oauth::TokenRefresher::RefreshFailedError => e
          raise AuthenticationError, "OAuth token refresh failed for '#{credential.name}': #{e.message}"
        end
      elsif credential.expired?
        raise AuthenticationError, "Credentials expired for '#{credential.name}'"
      end

      creds = credential.decrypt_credentials

      # For OAUTH2 credentials, merge credential_id and refresh_token
      if credential.auth_type == "OAUTH2"
        creds[:_credential_id] = credential.id
        refresh_token = credential.decrypt_refresh_token
        creds[:_refresh_token] = refresh_token if refresh_token.present?
      end

      creds
    end

    def record_failure(connection, action_name, input, error, start_time)
      duration_ms = start_time ? ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round : nil
      status = error.is_a?(Connectors::TimeoutError) ? "timeout" : "error"

      ConnectorExecution.record(
        project: @project,
        connection: connection,
        action_name: action_name,
        status: status,
        duration_ms: duration_ms,
        input_hash: input.present? ? Digest::SHA256.hexdigest(input.to_json) : nil,
        error_message: error.message,
        caller_service: @caller_service,
        caller_request_id: @caller_request_id
      )
    rescue StandardError => e
      Rails.logger.error "[Connectors::Executor] Failed to record execution failure: #{e.message}"
    end

    def truncate_output(output)
      json = output.to_json
      json.length > 10_000 ? { truncated: true, size: json.length } : output
    end
  end
end
