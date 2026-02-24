class ConnectorConnection < ApplicationRecord
  belongs_to :project
  belongs_to :connector
  belongs_to :connector_credential, optional: true
  has_many :connector_executions, dependent: :restrict_with_error

  validates :status, inclusion: { in: %w[connected disconnected error] }

  scope :active, -> { where(enabled: true) }
  scope :connected, -> { where(status: "connected", enabled: true) }
  scope :for_connector, ->(connector) { where(connector: connector) }

  def connected?
    status == "connected" && enabled?
  end

  def disconnected?
    status == "disconnected" || !enabled?
  end

  def mark_connected!
    update!(status: "connected", error_message: nil)
  end

  def mark_error!(message)
    update!(status: "error", error_message: message)
  end

  def disconnect!
    update!(status: "disconnected", enabled: false)
  end

  def record_execution!
    update_columns(
      last_executed_at: Time.current,
      execution_count: execution_count + 1
    )
  end

  def to_summary
    {
      id: id,
      connector_id: connector_id,
      connector_name: connector.piece_name,
      connector_display_name: connector.display_name,
      credential_id: connector_credential_id,
      name: name,
      status: status,
      enabled: enabled,
      last_executed_at: last_executed_at,
      execution_count: execution_count,
      created_at: created_at
    }
  end

  def to_detail
    to_summary.merge(
      config: config,
      error_message: error_message,
      connector: connector.to_catalog_entry,
      metadata: metadata
    )
  end
end
