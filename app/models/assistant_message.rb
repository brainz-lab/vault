class AssistantMessage < ApplicationRecord
  belongs_to :assistant_chat, touch: true

  enum :role, { user: 0, assistant: 1, tool_call: 2, tool_result: 3 }

  scope :chronological, -> { order(created_at: :asc) }
end
