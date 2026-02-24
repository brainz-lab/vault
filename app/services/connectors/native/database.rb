module Connectors
  module Native
    class Database < Base
      SUPPORTED_ADAPTERS = %w[postgresql mysql2].freeze

      def self.piece_name = "database"
      def self.display_name = "Database"
      def self.description = "Execute SQL queries against PostgreSQL or MySQL databases"
      def self.category = "data"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            adapter: { type: "string", description: "postgresql or mysql2", required: false },
            host: { type: "string", description: "Database host", required: true },
            port: { type: "number", description: "Database port", required: false },
            database: { type: "string", description: "Database name", required: true },
            username: { type: "string", description: "Database username", required: true },
            password: { type: "string", description: "Database password", required: true }
          }
        }
      end

      def self.actions
        [
          {
            "name" => "query",
            "displayName" => "Execute Query",
            "description" => "Execute a read-only SQL query and return results",
            "props" => {
              "sql" => { "type" => "string", "required" => true, "description" => "SQL query" },
              "binds" => { "type" => "array", "required" => false, "description" => "Bind parameters" }
            }
          },
          {
            "name" => "execute",
            "displayName" => "Execute Statement",
            "description" => "Execute a SQL statement (INSERT, UPDATE, DELETE)",
            "props" => {
              "sql" => { "type" => "string", "required" => true, "description" => "SQL statement" },
              "binds" => { "type" => "array", "required" => false, "description" => "Bind parameters" }
            }
          },
          {
            "name" => "list_tables",
            "displayName" => "List Tables",
            "description" => "List all tables in the database",
            "props" => {}
          },
          {
            "name" => "describe_table",
            "displayName" => "Describe Table",
            "description" => "Get column information for a table",
            "props" => {
              "table" => { "type" => "string", "required" => true, "description" => "Table name" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "query" then run_query(params)
        when "execute" then run_execute(params)
        when "list_tables" then list_tables
        when "describe_table" then describe_table(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def run_query(params)
        with_connection do |conn|
          result = conn.exec_query(params[:sql], "Connectors::Database Query", params[:binds] || [])
          { columns: result.columns, rows: result.rows, count: result.rows.size }
        end
      end

      def run_execute(params)
        with_connection do |conn|
          result = conn.execute(params[:sql], "Connectors::Database Execute")
          { affected_rows: result.cmd_tuples }
        end
      rescue ActiveRecord::StatementInvalid => e
        raise Connectors::Error, "SQL execution error: #{e.message}"
      end

      def list_tables
        with_connection do |conn|
          tables = conn.tables
          { tables: tables, count: tables.size }
        end
      end

      def describe_table(params)
        table = params[:table]
        with_connection do |conn|
          columns = conn.columns(table).map do |col|
            { name: col.name, type: col.sql_type, null: col.null, default: col.default }
          end
          { table: table, columns: columns, count: columns.size }
        end
      rescue ActiveRecord::StatementInvalid => e
        raise Connectors::Error, "Table not found or error: #{e.message}"
      end

      def with_connection(&block)
        if credentials[:host].present? || credentials[:database].present?
          with_external_connection(&block)
        else
          block.call(ActiveRecord::Base.connection)
        end
      end

      def with_external_connection
        adapter = credentials[:adapter] || "postgresql"
        unless SUPPORTED_ADAPTERS.include?(adapter)
          raise Connectors::Error, "Unsupported adapter: #{adapter}. Supported: #{SUPPORTED_ADAPTERS.join(', ')}"
        end

        config = {
          adapter: adapter,
          host: credentials[:host],
          port: credentials[:port] || 5432,
          database: credentials[:database],
          username: credentials[:username],
          password: credentials[:password]
        }.compact

        spec = ActiveRecord::DatabaseConfigurations::HashConfig.new("connectors", "primary", config)
        conn = ActiveRecord::Base.connection_handler.establish_connection(spec, owner_name: "Connectors::External")
        yield conn.connection
      ensure
        ActiveRecord::Base.connection_handler.remove_connection_pool("Connectors::External")
      end
    end
  end
end
