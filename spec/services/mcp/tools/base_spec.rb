require "rails_helper"

RSpec.describe Mcp::Tools::Base do
  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "defines DESCRIPTION" do
    expect(described_class::DESCRIPTION).to eq("Base tool")
  end

  it "defines INPUT_SCHEMA" do
    expect(described_class::INPUT_SCHEMA[:type]).to eq("object")
  end

  it "call raises NotImplementedError" do
    expect { tool.call({}) }.to raise_error(NotImplementedError)
  end

  it "success returns success hash" do
    result = tool.send(:success, { key: "value" })
    expect(result[:success]).to be true
    expect(result[:data]).to eq({ key: "value" })
  end

  it "error returns error hash" do
    result = tool.send(:error, "Something went wrong")
    expect(result[:success]).to be false
    expect(result[:error]).to eq("Something went wrong")
  end

  it "log_access creates audit log" do
    expect { tool.send(:log_access, action: "test_action") }.to change(AuditLog, :count).by(1)
  end
end
