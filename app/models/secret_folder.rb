class SecretFolder < ApplicationRecord
  belongs_to :project
  belongs_to :parent_folder, class_name: "SecretFolder", optional: true

  has_many :secrets, dependent: :nullify
  has_many :child_folders, class_name: "SecretFolder", foreign_key: :parent_folder_id

  validates :name, presence: true
  validates :path, presence: true, uniqueness: { scope: :project_id }

  before_validation :set_path

  scope :root, -> { where(parent_folder: nil) }
  scope :ordered, -> { order(:path) }

  def full_path
    if parent_folder
      "#{parent_folder.full_path}/#{name.parameterize}"
    else
      "/#{name.parameterize}"
    end
  end

  def secrets_count
    secrets.active.count
  end

  private

  def set_path
    self.path = full_path
  end
end
