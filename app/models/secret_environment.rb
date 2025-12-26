class SecretEnvironment < ApplicationRecord
  belongs_to :project
  belongs_to :parent_environment, class_name: "SecretEnvironment", optional: true

  has_many :secret_versions, dependent: :destroy
  has_many :child_environments, class_name: "SecretEnvironment", foreign_key: :parent_environment_id

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :slug, presence: true, uniqueness: { scope: :project_id },
                   format: { with: /\A[a-z0-9\-]+\z/ }

  before_validation :set_slug

  scope :ordered, -> { order(position: :asc) }

  def secrets_count
    SecretVersion.joins(:secret)
                 .where(secret_environment: self, current: true)
                 .where(secrets: { project_id: project_id, archived: false })
                 .count
  end

  def resolve_value(secret)
    # Check this environment first
    version = secret.current_version(self)
    return version.decrypt if version

    # Fall back to parent environment
    if parent_environment
      parent_environment.resolve_value(secret)
    else
      nil
    end
  end

  def all_secrets
    Secret.where(project_id: project_id, archived: false)
          .includes(:versions)
          .where(secret_versions: { secret_environment_id: id, current: true })
  end

  def export_env_file
    EnvFileGenerator.new(self).generate
  end

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
