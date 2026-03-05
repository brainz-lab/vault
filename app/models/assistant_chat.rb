class AssistantChat < ApplicationRecord
  has_many :assistant_messages, dependent: :destroy

  scope :recent, -> { order(updated_at: :desc) }

  def display_title
    title.presence || "New Chat"
  end
end
