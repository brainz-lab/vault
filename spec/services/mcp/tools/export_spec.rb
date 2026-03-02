require "rails_helper"

RSpec.describe Mcp::Tools::Export do
  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION is present" do
    expect(described_class::DESCRIPTION).to be_present
  end

  it "INPUT_SCHEMA is present" do
    expect(described_class::INPUT_SCHEMA).to be_present
  end
end
