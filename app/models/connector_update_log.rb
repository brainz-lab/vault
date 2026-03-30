# frozen_string_literal: true

class ConnectorUpdateLog < ApplicationRecord
  CHANGE_TYPES = %w[minor patch breaking].freeze
  STATUSES = %w[auto_applied pending_review rejected applied].freeze

  belongs_to :connector

  validates :change_type, presence: true, inclusion: { in: CHANGE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending_review") }
  scope :breaking, -> { where(change_type: "breaking") }
  scope :auto_applied, -> { where(status: "auto_applied") }
  scope :recent, -> { order(created_at: :desc).limit(100) }

  def apply!
    connector.update!(
      manifest_yaml: new_manifest_yaml,
      version: new_version,
      manifest_version: new_version,
      manifest_fetched_at: Time.current
    )
    update!(status: "applied", reviewed_at: Time.current)
  end

  def reject!
    update!(status: "rejected", reviewed_at: Time.current)
  end
end
