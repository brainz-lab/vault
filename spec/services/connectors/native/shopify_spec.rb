# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Shopify, type: :service do
  let(:credentials) { { store_domain: "mystore.myshopify.com", access_token: "shpat_test123", api_version: "2024-01" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://mystore.myshopify.com/admin/api/2024-01" }

  it_behaves_like "a native connector"

  describe "#execute list_products" do
    it "returns products" do
      stub_json_get("#{api_base}/products.json",
        body: { products: [
          { id: 1, title: "T-Shirt", vendor: "Acme", product_type: "Apparel", status: "active", variants: [{}], created_at: "2026-01-01", tags: "sale" }
        ] })

      result = connector.execute("list_products")
      expect(result[:products].first[:title]).to eq("T-Shirt")
      expect(result[:count]).to eq(1)
    end
  end

  describe "#execute get_product" do
    it "returns product details" do
      stub_json_get("#{api_base}/products/1.json",
        body: { product: { id: 1, title: "T-Shirt", body_html: "<p>Nice</p>", vendor: "Acme",
          product_type: "Apparel", status: "active", tags: "sale", variants: [], images: [],
          created_at: "2026-01-01", updated_at: "2026-01-02" } })

      result = connector.execute("get_product", product_id: "1")
      expect(result[:id]).to eq(1)
      expect(result[:title]).to eq("T-Shirt")
    end
  end

  describe "#execute list_orders" do
    it "returns orders" do
      stub_json_get("#{api_base}/orders.json",
        body: { orders: [
          { id: 100, order_number: 1001, email: "buyer@example.com", financial_status: "paid",
            fulfillment_status: nil, total_price: "29.99", currency: "USD", line_items: [{}], created_at: "2026-01-01" }
        ] })

      result = connector.execute("list_orders")
      expect(result[:orders].first[:total_price]).to eq("29.99")
    end
  end

  describe "#execute create_product" do
    it "creates a product" do
      stub_json_post("#{api_base}/products.json",
        body: { product: { id: 2, title: "Shoes", status: "draft" } })

      result = connector.execute("create_product", title: "Shoes", price: "49.99")
      expect(result[:success]).to be true
      expect(result[:id]).to eq(2)
    end
  end

  describe "#execute update_order" do
    it "updates an order" do
      stub_json_put("#{api_base}/orders/100.json",
        body: { order: { id: 100, order_number: 1001 } })

      result = connector.execute("update_order", order_id: "100", note: "Rush delivery")
      expect(result[:success]).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/products.json",
        body: { errors: "Not authorized" }, status: 401)

      expect { connector.execute("list_products") }
        .to raise_error(Connectors::AuthenticationError, /Shopify/)
    end

    it "raises RateLimitError on 429" do
      stub_json_get("#{api_base}/products.json",
        body: { errors: "Throttled" }, status: 429)

      expect { connector.execute("list_products") }
        .to raise_error(Connectors::RateLimitError)
    end
  end
end
