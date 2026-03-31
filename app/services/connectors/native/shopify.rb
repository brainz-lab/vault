# frozen_string_literal: true

module Connectors
  module Native
    class Shopify < Base
      def self.piece_name = "shopify"
      def self.display_name = "Shopify"
      def self.description = "Manage products, orders, and customers on Shopify stores"
      def self.category = "ecommerce"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/shopify.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            store_domain: { type: "string", description: "Shopify store domain (e.g., mystore.myshopify.com)", required: true },
            access_token: { type: "string", description: "Admin API Access Token", required: true },
            api_version: { type: "string", description: "API version (default: 2024-01)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to your Shopify admin → Settings → Apps and sales channels",
            "Click 'Develop apps' → 'Create an app'",
            "Configure Admin API scopes: read_products, write_products, read_orders, write_orders, read_customers",
            "Install the app and copy the Admin API Access Token",
            "Enter your store domain (e.g., mystore.myshopify.com)"
          ],
          docs_url: "https://shopify.dev/docs/apps/auth/admin-app-access-tokens"
        }
      end

      def self.actions
        [
          {
            "name" => "list_products",
            "displayName" => "List Products",
            "description" => "List products from the store",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max products (default: 50, max: 250)" },
              "status" => { "type" => "string", "required" => false, "description" => "Filter: active, draft, or archived" },
              "collection_id" => { "type" => "string", "required" => false, "description" => "Filter by collection ID" }
            }
          },
          {
            "name" => "get_product",
            "displayName" => "Get Product",
            "description" => "Get a single product by ID",
            "props" => {
              "product_id" => { "type" => "string", "required" => true, "description" => "Product ID" }
            }
          },
          {
            "name" => "list_orders",
            "displayName" => "List Orders",
            "description" => "List orders from the store",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max orders (default: 50, max: 250)" },
              "status" => { "type" => "string", "required" => false, "description" => "Filter: open, closed, cancelled, any (default: open)" },
              "financial_status" => { "type" => "string", "required" => false, "description" => "Filter: paid, unpaid, refunded, etc." },
              "created_at_min" => { "type" => "string", "required" => false, "description" => "Filter orders created after this date (ISO 8601)" }
            }
          },
          {
            "name" => "get_order",
            "displayName" => "Get Order",
            "description" => "Get a single order by ID",
            "props" => {
              "order_id" => { "type" => "string", "required" => true, "description" => "Order ID" }
            }
          },
          {
            "name" => "list_customers",
            "displayName" => "List Customers",
            "description" => "List customers from the store",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max customers (default: 50, max: 250)" },
              "query" => { "type" => "string", "required" => false, "description" => "Search query (email, name, etc.)" }
            }
          },
          {
            "name" => "create_product",
            "displayName" => "Create Product",
            "description" => "Create a new product in the store",
            "props" => {
              "title" => { "type" => "string", "required" => true, "description" => "Product title" },
              "body_html" => { "type" => "string", "required" => false, "description" => "Product description (HTML)" },
              "vendor" => { "type" => "string", "required" => false, "description" => "Product vendor" },
              "product_type" => { "type" => "string", "required" => false, "description" => "Product type" },
              "tags" => { "type" => "string", "required" => false, "description" => "Comma-separated tags" },
              "price" => { "type" => "string", "required" => false, "description" => "Default variant price" },
              "sku" => { "type" => "string", "required" => false, "description" => "Default variant SKU" }
            }
          },
          {
            "name" => "update_order",
            "displayName" => "Update Order",
            "description" => "Update an existing order",
            "props" => {
              "order_id" => { "type" => "string", "required" => true, "description" => "Order ID" },
              "note" => { "type" => "string", "required" => false, "description" => "Order note" },
              "tags" => { "type" => "string", "required" => false, "description" => "Comma-separated tags" },
              "email" => { "type" => "string", "required" => false, "description" => "Customer email" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_products" then list_products(params)
        when "get_product" then get_product(params)
        when "list_orders" then list_orders(params)
        when "get_order" then get_order(params)
        when "list_customers" then list_customers(params)
        when "create_product" then create_product(params)
        when "update_order" then update_order(params)
        else raise Connectors::ActionNotFoundError, "Unknown Shopify action: #{action}"
        end
      end

      private

      def list_products(params)
        query = { limit: [ (params[:limit] || 50).to_i, 250 ].min }
        query[:status] = params[:status] if params[:status].present?
        query[:collection_id] = params[:collection_id] if params[:collection_id].present?

        result = api_get("products.json", query)
        products = (result["products"] || []).map do |p|
          {
            id: p["id"], title: p["title"], vendor: p["vendor"],
            product_type: p["product_type"], status: p["status"],
            variants_count: p["variants"]&.size, created_at: p["created_at"],
            tags: p["tags"]
          }
        end
        { products: products, count: products.size }
      end

      def get_product(params)
        result = api_get("products/#{params[:product_id]}.json")
        p = result["product"]
        {
          id: p["id"], title: p["title"], body_html: p["body_html"],
          vendor: p["vendor"], product_type: p["product_type"], status: p["status"],
          tags: p["tags"], variants: p["variants"], images: p["images"]&.map { |i| i["src"] },
          created_at: p["created_at"], updated_at: p["updated_at"]
        }
      end

      def list_orders(params)
        query = { limit: [ (params[:limit] || 50).to_i, 250 ].min }
        query[:status] = params[:status] || "any"
        query[:financial_status] = params[:financial_status] if params[:financial_status].present?
        query[:created_at_min] = params[:created_at_min] if params[:created_at_min].present?

        result = api_get("orders.json", query)
        orders = (result["orders"] || []).map do |o|
          {
            id: o["id"], order_number: o["order_number"], email: o["email"],
            financial_status: o["financial_status"], fulfillment_status: o["fulfillment_status"],
            total_price: o["total_price"], currency: o["currency"],
            line_items_count: o["line_items"]&.size, created_at: o["created_at"]
          }
        end
        { orders: orders, count: orders.size }
      end

      def get_order(params)
        result = api_get("orders/#{params[:order_id]}.json")
        o = result["order"]
        {
          id: o["id"], order_number: o["order_number"], email: o["email"],
          financial_status: o["financial_status"], fulfillment_status: o["fulfillment_status"],
          total_price: o["total_price"], currency: o["currency"], note: o["note"],
          tags: o["tags"], line_items: o["line_items"], shipping_address: o["shipping_address"],
          billing_address: o["billing_address"], created_at: o["created_at"]
        }
      end

      def list_customers(params)
        query = { limit: [ (params[:limit] || 50).to_i, 250 ].min }

        path = if params[:query].present?
                 query[:query] = params[:query]
                 "customers/search.json"
        else
                 "customers.json"
        end

        result = api_get(path, query)
        customers = (result["customers"] || []).map do |c|
          {
            id: c["id"], email: c["email"],
            first_name: c["first_name"], last_name: c["last_name"],
            orders_count: c["orders_count"], total_spent: c["total_spent"],
            created_at: c["created_at"]
          }
        end
        { customers: customers, count: customers.size }
      end

      def create_product(params)
        product = { title: params[:title] }
        product[:body_html] = params[:body_html] if params[:body_html].present?
        product[:vendor] = params[:vendor] if params[:vendor].present?
        product[:product_type] = params[:product_type] if params[:product_type].present?
        product[:tags] = params[:tags] if params[:tags].present?

        if params[:price].present? || params[:sku].present?
          variant = {}
          variant[:price] = params[:price] if params[:price].present?
          variant[:sku] = params[:sku] if params[:sku].present?
          product[:variants] = [ variant ]
        end

        result = api_post("products.json", { product: product })
        p = result["product"]
        { success: true, id: p["id"], title: p["title"], status: p["status"] }
      end

      def update_order(params)
        order = {}
        order[:note] = params[:note] if params.key?(:note)
        order[:tags] = params[:tags] if params.key?(:tags)
        order[:email] = params[:email] if params.key?(:email)

        result = api_put("orders/#{params[:order_id]}.json", { order: order })
        o = result["order"]
        { success: true, id: o["id"], order_number: o["order_number"] }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["X-Shopify-Access-Token"] = access_token
          req.params = params
        end

        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}") do |req|
          req.headers["X-Shopify-Access-Token"] = access_token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{api_base}/#{path}") do |req|
          req.headers["X-Shopify-Access-Token"] = access_token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)

        unless resp.success?
          errors = data["errors"]
          error_msg = errors.is_a?(Hash) ? errors.values.flatten.join(", ") : errors.to_s
          raise Connectors::AuthenticationError, "Shopify: #{error_msg}" if resp.status == 401
          raise Connectors::RateLimitError, "Shopify rate limited" if resp.status == 429
          raise Connectors::Error, "Shopify API error: #{error_msg}"
        end

        data
      end

      def api_base
        version = credentials[:api_version] || "2024-01"
        "https://#{store_domain}/admin/api/#{version}"
      end

      def store_domain = credentials[:store_domain]
      def access_token = credentials[:access_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
