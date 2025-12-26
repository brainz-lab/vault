class Project < ApplicationRecord
  has_many :secret_environments, dependent: :destroy
  has_many :secret_folders, dependent: :destroy
  has_many :secrets, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :access_policies, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :encryption_keys, dependent: :destroy

  validates :platform_project_id, presence: true, uniqueness: true
  validates :api_key, uniqueness: true, allow_nil: true
  validates :ingest_key, uniqueness: true, allow_nil: true

  before_create :generate_keys
  after_create :create_default_environments

  # Find or create project for Platform integration
  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "production")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name || "Project #{platform_project_id}"
      p.environment = environment
    end
  end

  # Find project by API key
  def self.find_by_api_key(key)
    return nil unless key.present?
    find_by(api_key: key) || find_by(ingest_key: key)
  end

  private

  def generate_keys
    self.api_key ||= "vlt_api_#{SecureRandom.hex(16)}"
    self.ingest_key ||= "vlt_ingest_#{SecureRandom.hex(16)}"
  end

  def create_default_environments
    secret_environments.create!(name: "Development", slug: "development", position: 0, color: "#22c55e")
    secret_environments.create!(name: "Staging", slug: "staging", position: 1, color: "#eab308")
    secret_environments.create!(name: "Production", slug: "production", position: 2, color: "#ef4444", protected: true)
  end
end
