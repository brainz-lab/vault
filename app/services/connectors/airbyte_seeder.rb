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

      # Filter: only manifest-only and low-code connectors (executable without Docker)
      executable_sources = sources.reject { |s| s["tombstone"] == true }.select { |s| manifest_compatible?(s) }
      executable_destinations = destinations.reject { |d| d["tombstone"] == true }.select { |d| manifest_compatible?(d) }

      stats = {
        created: 0, updated: 0, skipped: 0, errors: 0,
        sources: executable_sources.length,
        destinations: executable_destinations.length,
        total_registry: sources.length + destinations.length
      }

      Rails.logger.info "[AirbyteSeeder] Registry: #{sources.length} sources + #{destinations.length} destinations → #{executable_sources.length + executable_destinations.length} executable (manifest-only/low-code)"

      total = executable_sources.length + executable_destinations.length
      count = 0

      executable_sources.each do |source|
        upsert_source(source, stats)
        count += 1
        print "\r  Seeding... #{count}/#{total}" if count % 50 == 0
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error "[AirbyteSeeder] Error seeding source #{source['name']}: #{e.message}"
      end

      executable_destinations.each do |dest|
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

    # Only seed connectors whose language indicates they can run via manifest interpreter
    def manifest_compatible?(entry)
      language = entry["language"]
      %w[manifest-only low-code].include?(language)
    end

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

      manifest_yaml = fetch_manifest_yaml(source)

      # Skip if we couldn't fetch the manifest — connector won't be executable
      unless manifest_yaml.present?
        stats[:skipped] += 1
        return
      end

      connector = Connector.find_or_initialize_by(piece_name: piece_name)
      was_new = connector.new_record?

      actions = build_source_actions_from_manifest(source, manifest_yaml)
      spec = source.dig("spec", "connectionSpecification") || {}

      connector.assign_attributes(
        display_name: source["name"] || slug.titleize,
        description: build_description(source, "source"),
        logo_url: source["iconUrl"],
        category: map_source_category(source["sourceType"]),
        connector_type: "airbyte",
        auth_type: extract_auth_type(spec),
        auth_schema: spec,
        setup_guide: build_setup_guide(source, spec),
        version: source["dockerImageTag"],
        package_name: source["dockerRepository"],
        actions: actions,
        triggers: [],
        metadata: build_source_metadata(source),
        installed: true,
        enabled: true,
        manifest_yaml: manifest_yaml,
        manifest_version: source["dockerImageTag"],
        manifest_fetched_at: Time.current
      )

      connector.save!
      was_new ? stats[:created] += 1 : stats[:updated] += 1
    end

    def upsert_destination(dest, stats)
      slug = extract_slug(dest["dockerRepository"], "destination")
      piece_name = "airbyte-dest-#{slug}"

      manifest_yaml = fetch_manifest_yaml(dest)

      unless manifest_yaml.present?
        stats[:skipped] += 1
        return
      end

      connector = Connector.find_or_initialize_by(piece_name: piece_name)
      was_new = connector.new_record?

      spec = dest.dig("spec", "connectionSpecification") || {}

      connector.assign_attributes(
        display_name: "#{dest['name'] || slug.titleize} (Destination)",
        description: build_description(dest, "destination"),
        logo_url: dest["iconUrl"],
        category: "data",
        connector_type: "airbyte",
        auth_type: extract_auth_type(spec),
        auth_schema: spec,
        setup_guide: build_setup_guide(dest, spec),
        version: dest["dockerImageTag"],
        package_name: dest["dockerRepository"],
        actions: build_destination_actions(dest),
        triggers: [],
        metadata: build_destination_metadata(dest),
        installed: true,
        enabled: true,
        manifest_yaml: manifest_yaml,
        manifest_version: dest["dockerImageTag"],
        manifest_fetched_at: Time.current
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

    def build_setup_guide(entry, spec)
      props = spec["properties"] || {}
      required = spec["required"] || []
      docs_url = entry["documentationUrl"]

      # Build steps from required credential fields
      steps = []
      steps << "Visit the #{entry['name']} documentation to obtain your credentials" if docs_url.present?

      required.each do |field_name|
        field_spec = props[field_name]
        next unless field_spec.is_a?(Hash)

        desc = field_spec["description"] || field_spec["title"] || field_name.titleize
        # Truncate very long descriptions
        desc = desc.truncate(200) if desc.length > 200

        if field_spec["airbyte_secret"]
          steps << "Obtain your #{field_name.titleize} (secret) — #{desc}"
        elsif field_spec["enum"]
          steps << "Select #{field_name.titleize}: #{field_spec['enum'].first(5).join(', ')}"
        else
          steps << "Provide #{field_name.titleize} — #{desc}"
        end
      end

      steps << "Enter your credentials in the form below and click Test Connection"

      # Build credential_fields for the UI form
      credential_fields = props.map do |name, field_spec|
        next unless field_spec.is_a?(Hash)
        {
          "name" => name,
          "label" => field_spec["title"] || name.titleize,
          "type" => infer_field_type(field_spec),
          "required" => required.include?(name),
          "description" => field_spec["description"]&.truncate(300),
          "placeholder" => field_spec["examples"]&.first&.to_s,
          "default" => field_spec["default"],
          "enum" => field_spec["enum"],
          "secret" => field_spec["airbyte_secret"] == true
        }
      end.compact

      {
        steps: steps,
        docs_url: docs_url,
        credential_fields: credential_fields
      }
    end

    def infer_field_type(field_spec)
      case field_spec["type"]
      when "integer", "number" then "number"
      when "boolean" then "boolean"
      when "array" then "json"
      when "object" then "json"
      else
        if field_spec["airbyte_secret"]
          "password"
        elsif field_spec["enum"]
          "select"
        elsif field_spec["multiline"]
          "textarea"
        else
          "text"
        end
      end
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

    def build_source_actions_from_manifest(source, manifest_yaml)
      manifest = YAML.safe_load(manifest_yaml, permitted_classes: [Date, Time])
      streams = manifest["streams"] || []
      return build_source_actions(source) if streams.empty?

      streams.map do |stream|
        resolved = stream.is_a?(Hash) ? stream : {}
        name = resolved["name"] || resolved["$ref"].to_s.split("/").last
        {
          "name" => name,
          "displayName" => name.to_s.titleize,
          "description" => "Read #{name} from #{source['name']}",
          "props" => {}
        }
      end
    rescue StandardError
      build_source_actions(source)
    end

    def fetch_manifest_yaml(entry)
      language = entry["language"]
      return nil unless language == "manifest-only" || language == "low-code"

      docker_repo = entry["dockerRepository"]
      slug = docker_repo.to_s.split("/").last
      return nil if slug.blank?

      paths = [
        "#{slug}/#{slug.tr('-', '_')}/manifest.yaml",
        "#{slug}/manifest.yaml"
      ]

      paths.each do |path|
        url = "https://raw.githubusercontent.com/airbytehq/airbyte/master/airbyte-integrations/connectors/#{path}"
        response = Faraday.get(url) { |f| f.options.timeout = 10; f.options.open_timeout = 5 }
        return response.body if response.success? && response.body.present?
      end
      nil
    rescue StandardError => e
      Rails.logger.debug "[AirbyteSeeder] Manifest fetch skipped for #{slug}: #{e.message}"
      nil
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
