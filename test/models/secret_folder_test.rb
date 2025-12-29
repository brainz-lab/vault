# frozen_string_literal: true

require "test_helper"

class SecretFolderTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid secret folder with all required attributes" do
    folder = SecretFolder.new(
      project: projects(:acme),
      name: "New Folder"
    )
    folder.valid? # Triggers set_path callback
    assert folder.valid?, folder.errors.full_messages.join(", ")
  end

  test "invalid without name" do
    folder = SecretFolder.new(project: projects(:acme))
    assert_not folder.valid?
    assert_includes folder.errors[:name], "can't be blank"
  end

  test "path must be unique per project" do
    existing = secret_folders(:acme_database)
    duplicate = SecretFolder.new(
      project: existing.project,
      name: existing.name
    )
    duplicate.valid? # Triggers set_path

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:path], "has already been taken"
  end

  test "path can be duplicated across projects" do
    folder1 = secret_folders(:acme_database)
    folder2 = SecretFolder.new(
      project: projects(:startup),
      name: folder1.name
    )
    folder2.valid? # Triggers set_path

    assert folder2.valid?
  end

  # ===========================================
  # Callbacks
  # ===========================================

  test "sets path from full_path before validation" do
    folder = SecretFolder.new(
      project: projects(:acme),
      name: "API Keys"
    )
    folder.valid?

    assert_equal "/api-keys", folder.path
  end

  test "sets nested path with parent folder" do
    parent = secret_folders(:acme_database)
    child = SecretFolder.new(
      project: projects(:acme),
      name: "Credentials",
      parent_folder: parent
    )
    child.valid?

    assert child.path.include?(parent.name.parameterize)
    assert child.path.include?("credentials")
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    folder = secret_folders(:acme_database)
    assert_respond_to folder, :project
    assert_equal projects(:acme), folder.project
  end

  test "belongs to parent_folder optionally" do
    folder = secret_folders(:acme_database)
    assert_respond_to folder, :parent_folder
  end

  test "has many secrets" do
    folder = secret_folders(:acme_database)
    assert_respond_to folder, :secrets
    assert folder.secrets.count >= 0
  end

  test "has many child_folders" do
    folder = secret_folders(:acme_database)
    assert_respond_to folder, :child_folders
  end

  test "dependent nullify keeps secrets but clears folder reference" do
    project = create_project
    folder = SecretFolder.create!(project: project, name: "Test Folder")
    secret = create_secret(project: project, folder: folder)

    assert_equal folder, secret.secret_folder

    folder.destroy!
    secret.reload

    assert_nil secret.secret_folder_id
    assert Secret.exists?(secret.id)
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "root scope returns folders without parent" do
    project = projects(:acme)
    root_folders = project.secret_folders.root

    root_folders.each do |folder|
      assert_nil folder.parent_folder_id
    end
  end

  test "ordered scope sorts by path" do
    project = projects(:acme)
    folders = project.secret_folders.ordered

    paths = folders.map(&:path)
    assert_equal paths, paths.sort
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "full_path returns parameterized name for root folder" do
    folder = SecretFolder.new(
      project: projects(:acme),
      name: "API Keys"
    )

    assert_equal "/api-keys", folder.full_path
  end

  test "full_path includes parent path for nested folder" do
    parent = secret_folders(:acme_database)
    child = SecretFolder.new(
      project: projects(:acme),
      name: "Credentials",
      parent_folder: parent
    )

    full_path = child.full_path
    assert full_path.start_with?(parent.full_path)
    assert full_path.end_with?("/credentials")
  end

  test "secrets_count returns count of active secrets" do
    folder = secret_folders(:acme_database)
    count = folder.secrets_count

    assert count.is_a?(Integer)
    assert count >= 0

    # Should only count active secrets
    active_count = folder.secrets.active.count
    assert_equal active_count, count
  end
end
