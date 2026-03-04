require "rails_helper"

RSpec.describe Mcp::Tools::GetSecret do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION includes 'Retrieve the value'" do
    expect(described_class::DESCRIPTION).to include("Retrieve the value")
  end

  it "INPUT_SCHEMA requires 'key'" do
    expect(described_class::INPUT_SCHEMA[:required]).to include("key")
  end

  describe "#call" do
    it "returns error when key is missing" do
      result = tool.call({})
      expect(result[:success]).to be false
      expect(result[:error]).to include("key is required")
    end

    it "returns error when secret is not found" do
      result = tool.call({ key: "NONEXISTENT_KEY" })
      expect(result[:success]).to be false
      expect(result[:error]).to include("not found")
    end
  end
end
