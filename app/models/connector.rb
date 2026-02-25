class Connector < ApplicationRecord
  CONNECTOR_TYPES = %w[activepieces native airbyte].freeze
  AUTH_TYPES = %w[SECRET_TEXT BASIC BASIC_AUTH CUSTOM_AUTH OAUTH2 NONE].freeze
  CATEGORIES = %w[communication crm data marketing productivity project_management sales support developer analytics ecommerce finance storage social automation ai accounting forms_and_surveys payment_processing human_resources business_intelligence content_and_files flow_control universal_ai core database file api other].freeze

  has_many :connector_credentials, dependent: :restrict_with_error
  has_many :connector_connections, dependent: :restrict_with_error

  validates :piece_name, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :connector_type, presence: true, inclusion: { in: CONNECTOR_TYPES }
  validates :auth_type, inclusion: { in: AUTH_TYPES }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :installed, -> { where(installed: true) }
  scope :by_type, ->(type) { where(connector_type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :native, -> { by_type("native") }
  scope :activepieces, -> { by_type("activepieces") }
  scope :search, ->(query) {
    where("piece_name ILIKE :q OR display_name ILIKE :q OR description ILIKE :q", q: "%#{query}%")
  }

  def activepieces?
    connector_type == "activepieces"
  end

  def native?
    connector_type == "native"
  end

  def airbyte?
    connector_type == "airbyte"
  end

  def action_names
    (actions || []).map { |a| a["name"] || a[:name] }
  end

  def find_action(name)
    (actions || []).find { |a| (a["name"] || a[:name]) == name.to_s }
  end

  def requires_auth?
    auth_type.present? && auth_type != "NONE"
  end

  def to_catalog_entry
    {
      id: id,
      piece_name: piece_name,
      display_name: display_name,
      description: description,
      logo_url: logo_url,
      category: category,
      connector_type: connector_type,
      auth_type: auth_type,
      auth_schema: auth_schema,
      actions: action_names,
      installed: installed,
      enabled: enabled
    }
  end

  def to_detail
    to_catalog_entry.merge(
      auth_schema: auth_schema,
      actions: actions,
      triggers: triggers,
      version: version,
      package_name: package_name,
      metadata: metadata
    )
  end
end
