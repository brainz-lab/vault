require "rails_helper"

RSpec.describe Connectors::Manifest::RecordSelector do
  describe "#extract" do
    context "with nested path" do
      subject(:selector) { described_class.new({ "field_path" => ["data", "items"] }) }

      it "extracts records from nested hash" do
        body = { "data" => { "items" => [{ "id" => 1 }, { "id" => 2 }] } }
        records = selector.extract(body)
        expect(records.length).to eq(2)
        expect(records.first["id"]).to eq(1)
      end
    end

    context "with single-level path" do
      subject(:selector) { described_class.new({ "field_path" => ["results"] }) }

      it "extracts records" do
        body = { "results" => [{ "name" => "a" }] }
        expect(selector.extract(body).length).to eq(1)
      end
    end

    context "with empty path" do
      subject(:selector) { described_class.new({ "field_path" => [] }) }

      it "returns response as-is when array" do
        body = [{ "id" => 1 }, { "id" => 2 }]
        expect(selector.extract(body).length).to eq(2)
      end
    end

    context "with single hash result" do
      subject(:selector) { described_class.new({ "field_path" => ["data"] }) }

      it "wraps in array" do
        body = { "data" => { "id" => 1, "name" => "single" } }
        records = selector.extract(body)
        expect(records.length).to eq(1)
        expect(records.first["name"]).to eq("single")
      end
    end

    context "with nil response" do
      subject(:selector) { described_class.new({ "field_path" => ["data"] }) }

      it "returns empty array" do
        expect(selector.extract(nil)).to eq([])
      end
    end

    context "with missing path" do
      subject(:selector) { described_class.new({ "field_path" => ["nonexistent"] }) }

      it "returns empty array" do
        expect(selector.extract({ "data" => [1, 2] })).to eq([])
      end
    end

    context "with wildcard" do
      subject(:selector) { described_class.new({ "field_path" => ["data", "*"] }) }

      it "returns array at that level" do
        body = { "data" => [{ "id" => 1 }, { "id" => 2 }] }
        expect(selector.extract(body).length).to eq(2)
      end
    end
  end
end
