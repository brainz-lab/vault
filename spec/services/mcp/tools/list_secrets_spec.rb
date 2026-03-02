require "rails_helper"

RSpec.describe Mcp::Tools::ListSecrets do
  before { setup_master_key }

  let(:project) { create(:project) }
  let(:environment) { project.secret_environments.find_by(slug: "development") }
  let(:tool) { described_class.new(project: project, environment: environment) }

  it "DESCRIPTION includes 'List all secret names'" do
    expect(described_class::DESCRIPTION).to include("List all secret names")
  end

  describe "#call" do
    before do
      create(:secret, project: project, key: "API_KEY")
      create(:secret, project: project, key: "DB_URL")
    end

    it "returns a success result" do
      result = tool.call({})
      expect(result[:success]).to be true
    end

    it "returns a secrets array" do
      result = tool.call({})
      expect(result[:data][:secrets]).to be_an(Array)
    end

    it "returns count as an integer" do
      result = tool.call({})
      expect(result[:data][:count]).to be_an(Integer)
      expect(result[:data][:count]).to eq(2)
    end

    it "returns the environment slug" do
      result = tool.call({})
      expect(result[:data][:environment]).to eq("development")
    end

    it "filters by folder" do
      folder = create(:secret_folder, project: project)
      create(:secret, project: project, key: "FOLDERED_KEY", secret_folder: folder)

      result = tool.call({ folder: folder.path })
      expect(result[:data][:secrets].map { |s| s[:key] }).to include("FOLDERED_KEY")
      expect(result[:data][:secrets].map { |s| s[:key] }).not_to include("API_KEY")
    end

    it "filters by tag" do
      tagged = create(:secret, project: project, key: "TAGGED_SECRET", tags: { "env" => "production" })

      result = tool.call({ tag: "env:production" })
      expect(result[:data][:secrets].map { |s| s[:key] }).to include("TAGGED_SECRET")
      expect(result[:data][:secrets].map { |s| s[:key] }).not_to include("API_KEY")
    end

    it "creates an audit log" do
      expect { tool.call({}) }.to change(AuditLog, :count).by(1)
    end
  end
end
