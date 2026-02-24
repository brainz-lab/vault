module Connectors
  class AirbyteSeeder
    REGISTRY_URL = "https://connectors.airbyte.com/files/registries/v0/oss_registry.json".freeze

    # Map Airbyte sourceType to our categories
    SOURCE_TYPE_MAP = {
      "api" => "api",
      "database" => "database",
      "file" => "file"
    }.freeze

    def seed!
      registry = fetch_registry
      sources = registry["sources"] || []
      destinations = registry["destinations"] || []

      stats = { created: 0, updated: 0, errors: 0, sources: sources.length, destinations: destinations.length }

      Rails.logger.info "[AirbyteSeeder] Fetched #{sources.length} sources + #{destinations.length} destinations"

      total = sources.length + destinations.length
      count = 0

      sources.each do |source|
        next if source["tombstone"] == true
        upsert_source(source, stats)
        count += 1
        print "\r  Seeding... #{count}/#{total}" if count % 50 == 0
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error "[AirbyteSeeder] Error seeding source #{source['name']}: #{e.message}"
      end

      destinations.each do |dest|
        next if dest["tombstone"] == true
        upsert_destination(dest, stats)
        count += 1
        print "\r  Seeding... #{count}/#{total}" if count % 50 == 0
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error "[AirbyteSeeder] Error seeding destination #{dest['name']}: #{e.message}"
      end

      puts "\r  Seeding... #{count}/#{total}"
      Rails.logger.info "[AirbyteSeeder] Complete: #{stats.inspect}"
      stats
    end

    private

    def fetch_registry
      response = Faraday.new(url: REGISTRY_URL) do |f|
        f.response :json
        f.options.timeout = 120
        f.options.open_timeout = 30
      end.get

      unless response.success?
        raise "Airbyte registry returned HTTP #{response.status}"
      end

      response.body
    end

    def upsert_source(source, stats)
      slug = extract_slug(source["dockerRepository"], "source")
      piece_name = "airbyte-source-#{slug}"

      connector = Connector.find_or_initialize_by(piece_name: piece_name)
      was_new = connector.new_record?

      connector.assign_attributes(
        display_name: source["name"] || slug.titleize,
        description: build_description(source, "source"),
        logo_url: source["iconUrl"],
        category: map_source_category(source["sourceType"]),
        connector_type: "airbyte",
        auth_type: extract_auth_type(source.dig("spec", "connectionSpecification")),
        auth_schema: source.dig("spec", "connectionSpecification") || {},
        version: source["dockerImageTag"],
        package_name: source["dockerRepository"],
        actions: build_source_actions(source),
        triggers: [],
        metadata: build_source_metadata(source),
        installed: source["releaseStage"] == "generally_available",
        enabled: true
      )

      connector.save!
      was_new ? stats[:created] += 1 : stats[:updated] += 1
    end

    def upsert_destination(dest, stats)
      slug = extract_slug(dest["dockerRepository"], "destination")
      piece_name = "airbyte-dest-#{slug}"

      connector = Connector.find_or_initialize_by(piece_name: piece_name)
      was_new = connector.new_record?

      connector.assign_attributes(
        display_name: "#{dest['name'] || slug.titleize} (Destination)",
        description: build_description(dest, "destination"),
        logo_url: dest["iconUrl"],
        category: "data",
        connector_type: "airbyte",
        auth_type: extract_auth_type(dest.dig("spec", "connectionSpecification")),
        auth_schema: dest.dig("spec", "connectionSpecification") || {},
        version: dest["dockerImageTag"],
        package_name: dest["dockerRepository"],
        actions: build_destination_actions(dest),
        triggers: [],
        metadata: build_destination_metadata(dest),
        installed: dest["releaseStage"] == "generally_available",
        enabled: true
      )

      connector.save!
      was_new ? stats[:created] += 1 : stats[:updated] += 1
    end

    def extract_slug(docker_repo, prefix)
      return "unknown" unless docker_repo.present?
      docker_repo.to_s.split("/").last.to_s.sub("#{prefix}-", "").sub("source-", "").sub("destination-", "")
    end

    def map_source_category(source_type)
      SOURCE_TYPE_MAP[source_type] || "data"
    end

    def build_description(entry, direction)
      parts = []
      parts << "Airbyte #{direction} connector for #{entry['name']}."
      parts << "Release: #{entry['releaseStage']}." if entry["releaseStage"]
      parts << "Support: #{entry['supportLevel']}." if entry["supportLevel"]
      parts.join(" ")
    end

    def extract_auth_type(spec)
      return nil unless spec.is_a?(Hash)

      props = spec["properties"] || {}

      # Check for common auth patterns in the spec
      if props["api_key"] || props["api_token"] || props["access_token"]
        "SECRET_TEXT"
      elsif props["username"] && props["password"]
        "BASIC"
      elsif props.values.any? { |v| v.is_a?(Hash) && v["airbyte_secret"] }
        "CUSTOM_AUTH"
      else
        "CUSTOM_AUTH"
      end
    end

    def build_source_actions(source)
      [
        {
          "name" => "sync",
          "displayName" => "Sync Data",
          "description" => "Extract data from #{source['name']}",
          "props" => {}
        }
      ]
    end

    def build_destination_actions(dest)
      [
        {
          "name" => "load",
          "displayName" => "Load Data",
          "description" => "Load data into #{dest['name']}",
          "props" => {}
        }
      ]
    end

    def build_source_metadata(source)
      {
        airbyte_id: source["sourceDefinitionId"],
        docker_repository: source["dockerRepository"],
        source_type: source["sourceType"],
        release_stage: source["releaseStage"],
        support_level: source["supportLevel"],
        language: source["language"],
        license: source["license"],
        documentation_url: source["documentationUrl"],
        release_date: source["releaseDate"]
      }.compact
    end

    def build_destination_metadata(dest)
      {
        airbyte_id: dest["destinationDefinitionId"],
        docker_repository: dest["dockerRepository"],
        release_stage: dest["releaseStage"],
        support_level: dest["supportLevel"],
        language: dest["language"],
        license: dest["license"],
        documentation_url: dest["documentationUrl"],
        release_date: dest["releaseDate"]
      }.compact
    end
  end
end
