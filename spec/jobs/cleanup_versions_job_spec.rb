require "rails_helper"

RSpec.describe CleanupVersionsJob do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }

  it "queues on low priority" do
    expect(described_class.new.queue_name).to eq("low")
  end

  it "performs without error" do
    expect { described_class.perform_now }.not_to raise_error
  end

  it "performs with specific project_id" do
    expect { described_class.perform_now(project_id: project.id) }.not_to raise_error
  end

  it "performs with custom keep_versions" do
    expect { described_class.perform_now(keep_versions: 5) }.not_to raise_error
  end

  it "keeps recent versions when count is within limit" do
    secret = create(:secret, project: project, key: "CLEANUP_ME")
    create(:secret_version, secret: secret, secret_environment: environment, version: 1)
    create(:secret_version, secret: secret, secret_environment: environment, version: 2, current: true)
    initial_count = secret.versions.count

    described_class.perform_now(project_id: project.id, keep_versions: 10, older_than_days: 0)

    expect(secret.versions.count).to eq(initial_count)
  end
end
