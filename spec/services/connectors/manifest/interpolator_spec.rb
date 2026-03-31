require "rails_helper"

RSpec.describe Connectors::Manifest::Interpolator do
  subject(:interpolator) { described_class.new(config: config, **extra) }

  let(:config) { { "api_key" => "secret123", "org" => "acme" } }
  let(:extra) { {} }

  describe "#interpolate" do
    context "with bracket notation" do
      it "resolves config['key']" do
        expect(interpolator.interpolate("{{ config['api_key'] }}")).to eq("secret123")
      end

      it "resolves config[\"key\"]" do
        expect(interpolator.interpolate('{{ config["org"] }}')).to eq("acme")
      end
    end

    context "with dot notation" do
      it "resolves config.key" do
        expect(interpolator.interpolate("{{ config.org }}")).to eq("acme")
      end
    end

    context "with mixed templates" do
      it "interpolates within surrounding text" do
        expect(interpolator.interpolate("https://{{ config.org }}.example.com/api"))
          .to eq("https://acme.example.com/api")
      end

      it "interpolates multiple templates" do
        result = interpolator.interpolate("{{ config.org }}-{{ config['api_key'] }}")
        expect(result).to eq("acme-secret123")
      end
    end

    context "with Hash values" do
      it "interpolates all values" do
        result = interpolator.interpolate({ "key" => "{{ config.org }}", "static" => "hello" })
        expect(result).to eq({ "key" => "acme", "static" => "hello" })
      end
    end

    context "with Array values" do
      it "interpolates each element" do
        result = interpolator.interpolate([ "{{ config.org }}", "static" ])
        expect(result).to eq([ "acme", "static" ])
      end
    end

    context "with missing keys" do
      it "returns empty string" do
        expect(interpolator.interpolate("{{ config['missing'] }}")).to eq("")
      end
    end

    context "with non-template strings" do
      it "passes through unchanged" do
        expect(interpolator.interpolate("no templates here")).to eq("no templates here")
      end
    end

    context "with non-string values" do
      it "passes through integers" do
        expect(interpolator.interpolate(42)).to eq(42)
      end

      it "passes through nil" do
        expect(interpolator.interpolate(nil)).to be_nil
      end

      it "passes through booleans" do
        expect(interpolator.interpolate(true)).to be(true)
      end
    end

    context "with response context" do
      let(:extra) { { response: { "next_cursor" => "abc123" } } }

      it "resolves response values" do
        expect(interpolator.interpolate("{{ response['next_cursor'] }}")).to eq("abc123")
      end
    end

    context "with parameters context" do
      let(:extra) { { parameters: { "page" => "5" } } }

      it "resolves parameter values" do
        expect(interpolator.interpolate("{{ parameters['page'] }}")).to eq("5")
      end
    end

    context "with stream_slice context" do
      let(:extra) { { stream_slice: { "partition" => "us-east-1" } } }

      it "resolves stream_slice values" do
        expect(interpolator.interpolate("{{ stream_slice['partition'] }}")).to eq("us-east-1")
      end
    end
  end
end
