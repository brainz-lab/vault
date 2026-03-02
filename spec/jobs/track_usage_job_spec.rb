require "rails_helper"

RSpec.describe TrackUsageJob do
  let(:project) { create(:project) }

  it "queues on low priority" do
    expect(described_class.new.queue_name).to eq("low")
  end

  it "performs without error when platform is not configured" do
    expect {
      described_class.perform_now(
        project_id: project.id,
        product: "vault",
        metric: "secrets_read",
        count: 1
      )
    }.not_to raise_error
  end

  it "handles missing project gracefully" do
    expect {
      described_class.perform_now(
        project_id: SecureRandom.uuid,
        product: "vault",
        metric: "secrets_read",
        count: 1
      )
    }.not_to raise_error
  end
end
