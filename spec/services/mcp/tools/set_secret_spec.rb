require "rails_helper"

RSpec.describe Mcp::Tools::SetSecret do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION is present" do
    expect(described_class::DESCRIPTION).to be_present
  end

  it "INPUT_SCHEMA requires 'key' and 'value'" do
    expect(described_class::INPUT_SCHEMA[:required]).to include("key")
    expect(described_class::INPUT_SCHEMA[:required]).to include("value")
  end

  describe "#call" do
    it "returns error when key is missing" do
      result = tool.call({ value: "some_value" })
      expect(result[:success]).to be false
      expect(result[:error]).to include("key is required")
    end

    it "returns error when value is missing" do
      result = tool.call({ key: "MY_SECRET" })
      expect(result[:success]).to be false
      expect(result[:error]).to include("value is required")
    end
  end
end
