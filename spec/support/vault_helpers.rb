module VaultHelpers
  def create_project_with_token(permissions: %w[read write admin])
    project = create(:project)
    token = create(:access_token, project: project, permissions: permissions)
    [ project, token, token.plain_token ]
  end

  def setup_master_key
    Rails.application.config.vault_master_key = "test-master-key-for-testing"
  end
end

RSpec.configure do |config|
  config.include VaultHelpers
end
