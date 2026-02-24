namespace :connectors do
  desc "Seed native connectors (webhook, database, email, file_storage)"
  task seed_native: :environment do
    stats = Connectors::NativeSeeder.new.seed!
    puts "Native connectors seeded: #{stats[:created]} created, #{stats[:updated]} updated"
  end

  desc "Sync connector catalog from sidecar"
  task sync_catalog: :environment do
    stats = Connectors::CatalogSync.new.sync!
    puts "Catalog synced: #{stats[:created]} created, #{stats[:updated]} updated, #{stats[:errors]} errors"
  end

  desc "Install a specific Activepieces connector"
  task :install_piece, [ :name ] => :environment do |_t, args|
    piece_name = args[:name]
    abort "Usage: rake connectors:install_piece[slack]" unless piece_name.present?

    sidecar_url = ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
    sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]
    package = "@activepieces/piece-#{piece_name}"

    puts "Installing #{package} via sidecar..."

    response = Faraday.new(url: sidecar_url) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 120
    end.post("/install") do |req|
      req.headers["Authorization"] = "Bearer #{sidecar_key}" if sidecar_key.present?
      req.body = { package: package }
    end

    if response.success? && response.body["success"]
      puts "Installed #{package} v#{response.body['version']}"
      puts "Run 'rake connectors:sync_catalog' to update the connector catalog"
    else
      abort "Failed to install: #{response.body['error'] || response.status}"
    end
  end

  desc "Show connector statistics"
  task stats: :environment do
    total = Connector.count
    native = Connector.native.count
    activepieces = Connector.activepieces.count
    installed = Connector.installed.count
    enabled = Connector.enabled.count

    puts "Connector Statistics:"
    puts "  Total:        #{total}"
    puts "  Native:       #{native}"
    puts "  Activepieces: #{activepieces}"
    puts "  Installed:    #{installed}"
    puts "  Enabled:      #{enabled}"

    puts "\nBy Category:"
    Connector.enabled.group(:category).count.sort_by { |_, v| -v }.each do |cat, count|
      puts "  #{cat}: #{count}"
    end
  end
end
