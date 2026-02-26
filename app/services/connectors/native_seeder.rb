module Connectors
  class NativeSeeder
    NATIVE_CONNECTORS = [
      Connectors::Native::Webhook,
      Connectors::Native::Database,
      Connectors::Native::Email,
      Connectors::Native::FileStorage,
      Connectors::Native::Apollo,
      Connectors::Native::Bitrix
    ].freeze

    def seed!
      stats = { created: 0, updated: 0 }

      NATIVE_CONNECTORS.each do |klass|
        connector = Connector.find_or_initialize_by(piece_name: klass.piece_name)
        was_new = connector.new_record?

        connector.assign_attributes(
          display_name: klass.display_name,
          description: klass.description,
          logo_url: klass.logo_url,
          category: klass.category,
          connector_type: "native",
          auth_type: klass.auth_type,
          auth_schema: klass.auth_schema,
          setup_guide: klass.respond_to?(:setup_guide) ? klass.setup_guide : {},
          actions: klass.actions,
          triggers: [],
          installed: true,
          enabled: true
        )

        connector.save!
        was_new ? stats[:created] += 1 : stats[:updated] += 1
      end

      Rails.logger.info "[NativeSeeder] Seeded native connectors: #{stats.inspect}"
      stats
    end
  end
end
