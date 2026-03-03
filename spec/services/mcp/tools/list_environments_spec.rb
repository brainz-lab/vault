require "rails_helper"

RSpec.describe Mcp::Tools::ListEnvironments do
  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION is present" do
    expect(described_class::DESCRIPTION).to be_present
  end

  it "INPUT_SCHEMA is present" do
    expect(described_class::INPUT_SCHEMA).to be_present
  end

  describe "#call" do
    it "returns a success result with a list of environments" do
      result = tool.call({})
      expect(result[:success]).to be true
      expect(result[:data][:environments]).to be_an(Array)
    end

    it "includes the current environment" do
      result = tool.call({})
      expect(result[:data][:current]).to be_present
    end

    it "includes environment details with name and slug" do
      result = tool.call({})
      env = result[:data][:environments].first
      expect(env[:name]).to be_present
      expect(env[:slug]).to be_present
    end
  end
end
