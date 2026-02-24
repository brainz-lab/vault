class ConnectorExecution < ApplicationRecord
  belongs_to :project
  belongs_to :connector_connection

  validates :action_name, presence: true
  validates :status, presence: true, inclusion: { in: %w[success error timeout] }

  # Append-only: prevent updates and deletes in production
  def readonly?
    return false if Rails.env.test?
    persisted?
  end

  def destroy
    return super if Rails.env.test?
    raise ActiveRecord::ReadOnlyRecord, "Connector executions are immutable"
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: %w[error timeout]) }
  scope :for_action, ->(name) { where(action_name: name) }
  scope :since, ->(time) { where("created_at >= ?", time) }

  def self.record(project:, connection:, action_name:, status:, duration_ms: nil, input_hash: nil, output_summary: nil, error_message: nil, caller_service: nil, caller_request_id: nil, metadata: {})
    create!(
      project: project,
      connector_connection: connection,
      action_name: action_name,
      status: status,
      duration_ms: duration_ms,
      input_hash: input_hash,
      output_summary: output_summary,
      error_message: error_message,
      caller_service: caller_service,
      caller_request_id: caller_request_id,
      metadata: metadata
    )
  end

  def success?
    status == "success"
  end

  def to_summary
    {
      id: id,
      action_name: action_name,
      status: status,
      duration_ms: duration_ms,
      caller_service: caller_service,
      error_message: error_message,
      created_at: created_at
    }
  end
end
