# frozen_string_literal: true

module Ai
  class AssistantService
    MAX_TOOL_ROUNDS = 10

    def initialize(chat, project: nil)
      @chat = chat
      @project = project
    end

    def send_message(user_content)
      @chat.assistant_messages.create!(role: :user, content: user_content)

      if @chat.title.blank?
        @chat.update!(title: user_content.truncate(60))
      end

      messages = build_messages
      tools = build_tools
      @ai_total_input_tokens = 0
      @ai_total_output_tokens = 0
      @ai_model = nil

      rounds = 0
      loop do
        rounds += 1
        response = call_claude(messages, tools)
        track_ai_usage(response)
        content_blocks = response["content"] || []

        text_parts = []
        tool_uses = []

        content_blocks.each do |block|
          case block["type"]
          when "text"
            text_parts << block["text"]
          when "tool_use"
            tool_uses << block
          end
        end

        if tool_uses.any?
          @chat.assistant_messages.create!(
            role: :tool_call,
            content: text_parts.join("\n").presence,
            metadata: {
              tool_calls: tool_uses.map { |tu| { id: tu["id"], name: tu["name"], input: tu["input"] } }
            }
          )

          assistant_content = content_blocks.map do |block|
            case block["type"]
            when "text"
              { type: "text", text: block["text"] }
            when "tool_use"
              { type: "tool_use", id: block["id"], name: block["name"], input: block["input"] }
            end
          end.compact
          messages << { role: "assistant", content: assistant_content }

          tool_results_content = []
          tool_uses.each do |tu|
            result = execute_tool(tu["name"], tu["input"])

            @chat.assistant_messages.create!(
              role: :tool_result,
              content: result.to_json,
              metadata: { tool_use_id: tu["id"], tool_name: tu["name"] }
            )

            tool_results_content << {
              type: "tool_result",
              tool_use_id: tu["id"],
              content: result.to_json
            }
          end

          messages << { role: "user", content: tool_results_content }
          break if rounds >= MAX_TOOL_ROUNDS
        else
          final_text = text_parts.join("\n")
          @chat.assistant_messages.create!(role: :assistant, content: final_text)
          report_ai_metrics
          return { role: "assistant", content: final_text }
        end
      end

      response = call_claude(messages, [])
      track_ai_usage(response)
      content_blocks = response["content"] || []
      final_text = content_blocks.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join("\n")
      @chat.assistant_messages.create!(role: :assistant, content: final_text)
      report_ai_metrics
      { role: "assistant", content: final_text }
    rescue => e
      Rails.logger.error "[AssistantService] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      error_msg = "I encountered an error processing your request: #{e.message}"
      @chat.assistant_messages.create!(role: :assistant, content: error_msg)
      report_ai_metrics
      { role: "assistant", content: error_msg }
    end

    private

    def build_messages
      raw = @chat.assistant_messages.chronological.to_a
      messages = []

      raw.each do |msg|
        case msg.role
        when "user"
          messages << { role: "user", content: msg.content }
        when "assistant"
          messages << { role: "assistant", content: msg.content }
        when "tool_call"
          content = []
          content << { type: "text", text: msg.content } if msg.content.present?
          (msg.metadata["tool_calls"] || []).each do |tc|
            content << { type: "tool_use", id: tc["id"], name: tc["name"], input: tc["input"] }
          end
          messages << { role: "assistant", content: content }
        when "tool_result"
          tool_result_block = {
            type: "tool_result",
            tool_use_id: msg.metadata["tool_use_id"],
            content: msg.content
          }
          if messages.last && messages.last[:role] == "user" && messages.last[:content].is_a?(Array)
            messages.last[:content] << tool_result_block
          else
            messages << { role: "user", content: [tool_result_block] }
          end
        end
      end

      messages
    end

    def build_tools
      Mcp::Server::TOOLS.map do |name, tool_class|
        {
          name: name,
          description: tool_class::DESCRIPTION,
          input_schema: tool_class::INPUT_SCHEMA
        }
      end
    rescue => e
      Rails.logger.warn "[AssistantService] Could not load MCP tools: #{e.message}"
      []
    end

    def system_prompt
      <<~PROMPT
        You are an AI assistant for Vault, a secure secrets and credentials management system. You help users manage secrets, API keys, SSH keys, and connector configurations.

        You have access to tools that let you search, create, and manage data. Use them to answer questions and execute actions.

        Guidelines:
        - Be concise and helpful
        - Format data clearly using markdown when appropriate
        - If a tool returns an error, explain it clearly to the user
        - For destructive actions, confirm with the user first
        - When showing lists, format them as readable tables or bullet points
      PROMPT
    end

    def call_claude(messages, tools)
      client = Anthropic::Client.new

      params = {
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        system: system_prompt,
        messages: messages
      }

      params[:tools] = tools if tools.any?

      client.messages(parameters: params)
    end

    def track_ai_usage(response)
      return unless response.is_a?(Hash) && response["usage"]

      @ai_model ||= response["model"]
      @ai_total_input_tokens += response["usage"]["input_tokens"].to_i
      @ai_total_output_tokens += response["usage"]["output_tokens"].to_i
    end

    def report_ai_metrics
      return unless defined?(BrainzLab::PlatformClient::CurrentTransaction)
      return if @ai_total_input_tokens.to_i.zero? && @ai_total_output_tokens.to_i.zero?

      tx = BrainzLab::PlatformClient::CurrentTransaction.get
      return unless tx

      tx[:ai_provider] = "anthropic"
      tx[:ai_model] = @ai_model
      tx[:ai_input_tokens] = @ai_total_input_tokens
      tx[:ai_output_tokens] = @ai_total_output_tokens
    end

    def execute_tool(name, arguments)
      tool_class = Mcp::Server::TOOLS[name]
      raise "Unknown tool: #{name}" unless tool_class

      tool = tool_class.new(
        project: @project,
        environment: "development"
      )
      tool.call(arguments.symbolize_keys)
    rescue => e
      { error: e.message }
    end
  end
end
