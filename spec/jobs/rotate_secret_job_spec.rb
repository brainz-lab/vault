require "rails_helper"

RSpec.describe RotateSecretJob do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:secret) { create(:secret, project: project) }

  it "queues on default priority" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "generates random value for api_key type" do
    secret.update!(tags: { "type" => "api_key" })
    value = described_class.new.send(:generate_random_value, secret)
    expect(value.length).to eq(64)
  end

  it "generates random value for password type" do
    secret.update!(tags: { "type" => "password" })
    value = described_class.new.send(:generate_random_value, secret)
    expect(value.length).to eq(32)
  end

  it "generates random value for jwt_secret type" do
    secret.update!(tags: { "type" => "jwt_secret" })
    value = described_class.new.send(:generate_random_value, secret)
    expect(value.length).to be > 0
  end

  it "generates random value for default type" do
    secret.update!(tags: {})
    value = described_class.new.send(:generate_random_value, secret)
    expect(value.length).to eq(64)
  end
end
