require "rails_helper"

RSpec.describe Mcp::Tools::DeleteSecret do
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

    context "with an existing secret" do
      let!(:secret) { create(:secret, project: project, key: "DELETE_ME") }

      it "archives the secret" do
        tool.call({ key: "DELETE_ME" })
        expect(secret.reload.archived?).to be true
      end

      it "creates audit logs" do
        # archive! creates 1 audit log + log_access in the tool creates another = 2 total
        expect { tool.call({ key: "DELETE_ME" }) }.to change(AuditLog, :count).by(2)
      end
    end
  end
end
