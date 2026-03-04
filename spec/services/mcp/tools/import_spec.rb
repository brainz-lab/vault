require "rails_helper"

RSpec.describe Mcp::Tools::Import do
  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION is present" do
    expect(described_class::DESCRIPTION).to be_present
  end

  it "INPUT_SCHEMA requires 'content'" do
    expect(described_class::INPUT_SCHEMA[:required]).to include("content")
  end

  describe "#call" do
    it "returns error when content is missing" do
      result = tool.call({})
      expect(result[:success]).to be false
      expect(result[:error]).to include("content is required")
    end
  end
end
