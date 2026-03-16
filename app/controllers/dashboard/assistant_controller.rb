module Dashboard
  class AssistantController < BaseController
    before_action :set_chat, only: [ :show, :message ]

    def index
      @chats = AssistantChat.where(user_id: assistant_user_id).recent.limit(50)
    end

    def show
      @messages = @chat.assistant_messages.chronological
    end

    def create
      chat = AssistantChat.create!(user_id: assistant_user_id)
      redirect_to dashboard_assistant_path(chat)
    end

    def message
      user_content = params[:content]&.strip
      count_before = @chat.assistant_messages.count

      service = Ai::AssistantService.new(@chat, project: current_project)
      result = service.send_message(user_content)

      new_messages = @chat.assistant_messages.chronological.offset(count_before)
      tool_calls = new_messages.where(role: :tool_call).map do |msg|
        {
          type: "tool_call",
          tool_calls: msg.metadata["tool_calls"]&.map { |tc| { name: tc["name"], input: tc["input"] } }
        }
      end

      render json: {
        role: "assistant",
        content: result[:content],
        tool_calls: tool_calls
      }
    end

    private

    def assistant_user_id
      session[:user_id] || "dev_user"
    end

    def set_chat
      @chat = AssistantChat.find(params[:id])
    end
  end
end
