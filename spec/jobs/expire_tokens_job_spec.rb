require "rails_helper"

RSpec.describe ExpireTokensJob do
  let(:project) { create(:project) }

  it "queues on low priority" do
    expect(described_class.new.queue_name).to eq("low")
  end

  it "revokes expired tokens" do
    token = create(:access_token, project: project, expires_at: 1.day.ago)

    described_class.perform_now

    token.reload
    expect(token.revoked?).to be true
  end

  it "does not revoke active non-expired tokens" do
    token = create(:access_token, project: project, expires_at: 1.day.from_now)

    described_class.perform_now

    token.reload
    expect(token.revoked?).to be false
  end

  it "does not revoke tokens without expiry" do
    token = create(:access_token, project: project, expires_at: nil)

    described_class.perform_now

    token.reload
    expect(token.revoked?).to be false
  end

  it "creates audit log for expired tokens" do
    # Ensure no other expired tokens exist
    AccessToken.where("expires_at < ?", Time.current).update_all(revoked_at: Time.current)

    create(:access_token, project: project, expires_at: 1.day.ago)

    expect { described_class.perform_now }.to change(AuditLog, :count).by(1)
  end
end
