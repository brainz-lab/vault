require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  describe "#icon" do
    %i[overview secrets environments access_tokens audit_logs provider_keys settings mcp].each do |icon_name|
      it "returns html safe svg for #{icon_name}" do
        result = helper.icon(icon_name)
        expect(result).to be_present
        expect(result).to be_html_safe
        expect(result).to include("<svg")
      end
    end

    it "returns nil for unknown icon" do
      expect(helper.icon(:unknown_icon)).to be_nil
    end
  end

  describe "#action_badge_class" do
    it "returns badge-green for create actions" do
      expect(helper.action_badge_class("create_secret")).to eq("badge-green")
      expect(helper.action_badge_class("create_token")).to eq("badge-green")
    end

    it "returns badge-blue for update actions" do
      expect(helper.action_badge_class("update_secret")).to eq("badge-blue")
      expect(helper.action_badge_class("set_value")).to eq("badge-blue")
    end

    it "returns badge-red for delete actions" do
      expect(helper.action_badge_class("delete_secret")).to eq("badge-red")
      expect(helper.action_badge_class("archive_secret")).to eq("badge-red")
      expect(helper.action_badge_class("revoke_token")).to eq("badge-red")
    end

    it "returns badge-gray for read actions" do
      expect(helper.action_badge_class("read_secret")).to eq("badge-gray")
      expect(helper.action_badge_class("get_value")).to eq("badge-gray")
      expect(helper.action_badge_class("list_secrets")).to eq("badge-gray")
      expect(helper.action_badge_class("export_secrets")).to eq("badge-gray")
    end

    it "returns badge-yellow for rollback" do
      expect(helper.action_badge_class("rollback_secret")).to eq("badge-yellow")
    end

    it "returns badge-orange for import" do
      expect(helper.action_badge_class("import_secrets")).to eq("badge-orange")
    end

    it "returns badge-gray for unknown actions" do
      expect(helper.action_badge_class("unknown_action")).to eq("badge-gray")
    end
  end

  describe "#provider_badge_class" do
    {
      "openai" => "bg-green-100 text-green-700",
      "anthropic" => "bg-orange-100 text-orange-700",
      "google" => "bg-blue-100 text-blue-700",
      "azure" => "bg-sky-100 text-sky-700",
      "cohere" => "bg-purple-100 text-purple-700",
      "mistral" => "bg-indigo-100 text-indigo-700",
      "groq" => "bg-yellow-100 text-yellow-700",
      "replicate" => "bg-pink-100 text-pink-700",
      "huggingface" => "bg-amber-100 text-amber-700"
    }.each do |provider, expected_class|
      it "returns correct class for #{provider}" do
        expect(helper.provider_badge_class(provider)).to eq(expected_class)
        expect(helper.provider_badge_class(provider.upcase)).to eq(expected_class)
      end
    end

    it "returns default class for unknown providers" do
      expect(helper.provider_badge_class("unknown_provider")).to eq("bg-stone-100 text-stone-700")
    end
  end
end
