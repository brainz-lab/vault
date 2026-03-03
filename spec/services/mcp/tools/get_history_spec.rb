require "rails_helper"

RSpec.describe Mcp::Tools::GetHistory do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION is present" do
    expect(described_class::DESCRIPTION).to be_present
  end

  it "INPUT_SCHEMA requires 'key'" do
    expect(described_class::INPUT_SCHEMA[:required]).to include("key")
  end

  describe "#call" do
    it "returns error when key is missing" do
      result = tool.call({})
      expect(result[:success]).to be false
      expect(result[:error]).to include("key")
    end

    it "returns error when secret is not found" do
      result = tool.call({ key: "NONEXISTENT_KEY" })
      expect(result[:success]).to be false
      expect(result[:error]).to include("not found")
    end

    context "with an existing secret and versions" do
      let!(:secret) { create(:secret, project: project, key: "HISTORY_KEY") }

      before do
        secret.set_value(environment, "value_v1", note: "Initial")
        secret.set_value(environment, "value_v2", note: "Updated")
      end

      it "returns a success result with version history" do
        result = tool.call({ key: "HISTORY_KEY" })
        expect(result[:success]).to be true
        expect(result[:data][:key]).to eq("HISTORY_KEY")
        expect(result[:data][:versions]).to be_an(Array)
      end

      it "creates an audit log" do
        expect { tool.call({ key: "HISTORY_KEY" }) }.to change(AuditLog, :count).by(1)
      end
    end
  end
end
