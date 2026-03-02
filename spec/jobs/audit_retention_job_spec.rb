require "rails_helper"

RSpec.describe AuditRetentionJob do
  let(:project) { create(:project) }

  it "queues on low priority" do
    expect(described_class.new.queue_name).to eq("low")
  end

  it "performs without error" do
    expect { described_class.perform_now }.not_to raise_error
  end

  it "performs with specific project_id" do
    expect { described_class.perform_now(project_id: project.id) }.not_to raise_error
  end

  it "performs with custom older_than_days" do
    expect { described_class.perform_now(older_than_days: 30) }.not_to raise_error
  end

  it "identifies old logs for export without error" do
    create(:audit_log, project: project)

    expect { described_class.perform_now(project_id: project.id, older_than_days: 0) }.not_to raise_error
  end
end
