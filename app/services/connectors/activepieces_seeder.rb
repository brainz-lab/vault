module Connectors
  class ActivepiecesSeeder
    API_URL = "https://cloud.activepieces.com/api/v1/pieces".freeze

    # Map Activepieces categories to our normalized categories
    CATEGORY_MAP = {
      "ARTIFICIAL_INTELLIGENCE" => "ai",
      "PRODUCTIVITY" => "productivity",
      "MARKETING" => "marketing",
      "COMMUNICATION" => "communication",
      "SALES_AND_CRM" => "crm",
      "CONTENT_AND_FILES" => "content_and_files",
      "DEVELOPER_TOOLS" => "developer",
      "BUSINESS_INTELLIGENCE" => "business_intelligence",
      "CORE" => "core",
      "COMMERCE" => "ecommerce",
      "FORMS_AND_SURVEYS" => "forms_and_surveys",
      "ACCOUNTING" => "accounting",
      "CUSTOMER_SUPPORT" => "support",
      "PAYMENT_PROCESSING" => "payment_processing",
      "UNIVERSAL_AI" => "universal_ai",
      "FLOW_CONTROL" => "flow_control",
      "HUMAN_RESOURCES" => "human_resources"
    }.freeze

    def seed!
      pieces = fetch_pieces
      stats = { created: 0, updated: 0, errors: 0, total: pieces.length }

      Rails.logger.info "[ActivepiecesSeeder] Fetched #{pieces.length} pieces from API"

      pieces.each_with_index do |piece, i|
        upsert_piece(piece, stats)
        print "\r  Seeding... #{i + 1}/#{pieces.length}" if (i + 1) % 50 == 0 || i == pieces.length - 1
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error "[ActivepiecesSeeder] Error seeding #{piece['name']}: #{e.message}"
      end

      puts "" # newline after progress
      Rails.logger.info "[ActivepiecesSeeder] Complete: #{stats.inspect}"
      stats
    end

    private

    def fetch_pieces
      response = Faraday.new(url: API_URL) do |f|
        f.response :json
        f.options.timeout = 120
        f.options.open_timeout = 30
      end.get

      unless response.success?
        raise "Activepieces API returned HTTP #{response.status}"
      end

      response.body
    end

    def upsert_piece(piece, stats)
      # Extract slug from package name: @activepieces/piece-slack -> slack
      package_name = piece["name"] || ""
      slug = package_name.sub("@activepieces/piece-", "")

      connector = Connector.find_or_initialize_by(piece_name: slug)
      was_new = connector.new_record?

      connector.assign_attributes(
        display_name: piece["displayName"] || slug.titleize,
        description: piece["description"],
        logo_url: piece["logoUrl"],
        category: map_category(piece["categories"]),
        connector_type: "activepieces",
        auth_type: normalize_auth_type(piece.dig("auth", "type")),
        auth_schema: piece["auth"] || {},
        version: piece["version"],
        package_name: package_name,
        actions: build_actions_placeholder(piece["actions"]),
        triggers: build_triggers_placeholder(piece["triggers"]),
        metadata: {
          activepieces_id: piece["id"],
          authors: piece["authors"],
          categories: piece["categories"],
          project_usage: piece["projectUsage"],
          minimum_supported_release: piece["minimumSupportedRelease"],
          maximum_supported_release: piece["maximumSupportedRelease"]
        }.compact,
        installed: true,
        enabled: true
      )

      connector.save!
      was_new ? stats[:created] += 1 : stats[:updated] += 1
    end

    def map_category(categories)
      return "other" unless categories.is_a?(Array) && categories.any?

      # Use the first category that maps to a known value
      categories.each do |cat|
        mapped = CATEGORY_MAP[cat]
        return mapped if mapped && Connector::CATEGORIES.include?(mapped)
      end

      "other"
    end

    def normalize_auth_type(type)
      return nil unless type.present?
      return "BASIC" if type == "BASIC_AUTH"
      Connector::AUTH_TYPES.include?(type) ? type : nil
    end

    # The list API returns action/trigger counts, not full definitions.
    # We store placeholder entries — full details come from sidecar sync.
    def build_actions_placeholder(count)
      return [] unless count.is_a?(Integer) && count > 0
      count.times.map { |i| { "name" => "action_#{i + 1}", "displayName" => "Action #{i + 1}" } }
    end

    def build_triggers_placeholder(count)
      return [] unless count.is_a?(Integer) && count > 0
      count.times.map { |i| { "name" => "trigger_#{i + 1}", "displayName" => "Trigger #{i + 1}" } }
    end
  end
end
