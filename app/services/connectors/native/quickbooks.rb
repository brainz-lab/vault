# frozen_string_literal: true

module Connectors
  module Native
    class Quickbooks < Base
      def self.piece_name = "quickbooks"
      def self.display_name = "QuickBooks"
      def self.description = "Manage invoices, customers, and payments in QuickBooks Online"
      def self.category = "accounting"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/quickbooks.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            access_token: { type: "string", description: "OAuth 2.0 Access Token", required: true },
            realm_id: { type: "string", description: "Company ID (Realm ID)", required: true },
            environment: { type: "string", description: "Environment: sandbox or production (default: production)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://developer.intuit.com → Dashboard → Create an app",
            "Configure OAuth 2.0 with scopes: com.intuit.quickbooks.accounting",
            "Use OAuth playground or your app to get Access Token + Realm ID",
            "Copy the Realm ID from the URL after connecting your company"
          ],
          docs_url: "https://developer.intuit.com/app/developer/qbo/docs/get-started"
        }
      end

      def self.actions
        [
          {
            "name" => "list_invoices",
            "displayName" => "List Invoices",
            "description" => "Query invoices",
            "props" => {
              "query" => { "type" => "string", "required" => false, "description" => "SQL-like query (e.g., SELECT * FROM Invoice WHERE Balance > '0')" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "create_invoice",
            "displayName" => "Create Invoice",
            "description" => "Create a new invoice",
            "props" => {
              "customer_id" => { "type" => "string", "required" => true, "description" => "Customer reference ID" },
              "line_items" => { "type" => "json", "required" => true, "description" => "Array of { description, amount, quantity }" },
              "due_date" => { "type" => "string", "required" => false, "description" => "Due date (YYYY-MM-DD)" }
            }
          },
          {
            "name" => "list_customers",
            "displayName" => "List Customers",
            "description" => "Query customers",
            "props" => {
              "query" => { "type" => "string", "required" => false, "description" => "SQL-like query (e.g., SELECT * FROM Customer WHERE Active = true)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "create_customer",
            "displayName" => "Create Customer",
            "description" => "Create a new customer",
            "props" => {
              "display_name" => { "type" => "string", "required" => true, "description" => "Customer display name" },
              "email" => { "type" => "string", "required" => false, "description" => "Email address" },
              "phone" => { "type" => "string", "required" => false, "description" => "Phone number" },
              "company_name" => { "type" => "string", "required" => false, "description" => "Company name" }
            }
          },
          {
            "name" => "list_payments",
            "displayName" => "List Payments",
            "description" => "Query payments",
            "props" => {
              "query" => { "type" => "string", "required" => false, "description" => "SQL-like query" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "get_company_info",
            "displayName" => "Get Company Info",
            "description" => "Get company information",
            "props" => {}
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_invoices" then list_invoices(params)
        when "create_invoice" then create_invoice(params)
        when "list_customers" then list_customers(params)
        when "create_customer" then create_customer(params)
        when "list_payments" then list_payments(params)
        when "get_company_info" then get_company_info(params)
        else raise Connectors::ActionNotFoundError, "Unknown QuickBooks action: #{action}"
        end
      end

      private

      def list_invoices(params)
        limit = (params[:limit] || 25).to_i
        sql = params[:query] || "SELECT * FROM Invoice MAXRESULTS #{limit}"
        result = qb_query(sql)
        invoices = (result.dig("QueryResponse", "Invoice") || []).map do |i|
          { id: i["Id"], doc_number: i["DocNumber"], customer: i.dig("CustomerRef", "name"),
            total: i["TotalAmt"], balance: i["Balance"], due_date: i["DueDate"],
            status: i["Balance"].to_f.zero? ? "paid" : "unpaid", created: i["MetaData"]&.dig("CreateTime") }
        end
        { invoices: invoices, count: invoices.size }
      end

      def create_invoice(params)
        lines = parse_json(params[:line_items])
        line_items = lines.map.with_index(1) do |item, idx|
          {
            LineNum: idx, Amount: item["amount"].to_f,
            DetailType: "SalesItemLineDetail",
            Description: item["description"],
            SalesItemLineDetail: { Qty: (item["quantity"] || 1).to_i, UnitPrice: item["amount"].to_f }
          }
        end

        body = {
          CustomerRef: { value: params[:customer_id] },
          Line: line_items
        }
        body[:DueDate] = params[:due_date] if params[:due_date].present?

        result = api_post("invoice", body)
        inv = result["Invoice"]
        { success: true, id: inv["Id"], doc_number: inv["DocNumber"], total: inv["TotalAmt"] }
      end

      def list_customers(params)
        limit = (params[:limit] || 25).to_i
        sql = params[:query] || "SELECT * FROM Customer MAXRESULTS #{limit}"
        result = qb_query(sql)
        customers = (result.dig("QueryResponse", "Customer") || []).map do |c|
          { id: c["Id"], display_name: c["DisplayName"], company: c["CompanyName"],
            email: c.dig("PrimaryEmailAddr", "Address"), phone: c.dig("PrimaryPhone", "FreeFormNumber"),
            balance: c["Balance"], active: c["Active"] }
        end
        { customers: customers, count: customers.size }
      end

      def create_customer(params)
        body = { DisplayName: params[:display_name] }
        body[:PrimaryEmailAddr] = { Address: params[:email] } if params[:email].present?
        body[:PrimaryPhone] = { FreeFormNumber: params[:phone] } if params[:phone].present?
        body[:CompanyName] = params[:company_name] if params[:company_name].present?

        result = api_post("customer", body)
        c = result["Customer"]
        { success: true, id: c["Id"], display_name: c["DisplayName"] }
      end

      def list_payments(params)
        limit = (params[:limit] || 25).to_i
        sql = params[:query] || "SELECT * FROM Payment MAXRESULTS #{limit}"
        result = qb_query(sql)
        payments = (result.dig("QueryResponse", "Payment") || []).map do |p|
          { id: p["Id"], total: p["TotalAmt"], customer: p.dig("CustomerRef", "name"),
            date: p["TxnDate"], payment_method: p.dig("PaymentMethodRef", "name") }
        end
        { payments: payments, count: payments.size }
      end

      def get_company_info(params)
        result = qb_query("SELECT * FROM CompanyInfo")
        info = result.dig("QueryResponse", "CompanyInfo", 0) || {}
        { name: info["CompanyName"], legal_name: info["LegalName"],
          email: info.dig("Email", "Address"), phone: info.dig("PrimaryPhone", "FreeFormNumber"),
          country: info.dig("Country"), fiscal_year_start: info["FiscalYearStartMonth"] }
      end

      def qb_query(sql)
        api_get("query", query: sql)
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"] = "application/json"
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.headers["Accept"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          fault = data["Fault"]
          error = fault ? fault["Error"]&.map { |e| e["Message"] }&.join(", ") : "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "QuickBooks: #{error}" if resp.status == 401
          raise Connectors::RateLimitError, "QuickBooks rate limited" if resp.status == 429
          raise Connectors::Error, "QuickBooks API error: #{error}"
        end
        data
      end

      def api_base
        env = credentials[:environment] == "sandbox" ? "sandbox-" : ""
        "https://#{env}quickbooks.api.intuit.com/v3/company/#{realm_id}"
      end

      def access_token = credentials[:access_token]
      def realm_id = credentials[:realm_id]

      def parse_json(value)
        return value if value.is_a?(Array) || value.is_a?(Hash)
        JSON.parse(value) rescue value
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
