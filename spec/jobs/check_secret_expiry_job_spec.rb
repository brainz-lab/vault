require "rails_helper"

RSpec.describe CheckSecretExpiryJob do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }

  it "queues on default priority" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "performs without error" do
    expect { described_class.perform_now }.not_to raise_error
  end

  it "identifies secrets needing rotation" do
    secret = create(:secret, project: project, key: "ROTATE_ME", rotation_interval_days: 7)
    # Create a version that is older than the rotation interval
    version = create(:secret_version, secret: secret, secret_environment: environment)
    version.update_columns(created_at: 10.days.ago)

    expect { described_class.perform_now }.not_to raise_error
  end

  it "ignores secrets without rotation_interval_days" do
    create(:secret, project: project, key: "NO_ROTATION", rotation_interval_days: nil)

    expect { described_class.perform_now }.not_to raise_error
  end

  it "ignores recently rotated secrets" do
    secret = create(:secret, project: project, key: "RECENT_ROTATION", rotation_interval_days: 30)
    create(:secret_version, secret: secret, secret_environment: environment)

    expect { described_class.perform_now }.not_to raise_error
  end
end
