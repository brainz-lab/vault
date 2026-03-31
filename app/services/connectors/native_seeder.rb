module Connectors
  class NativeSeeder
    NATIVE_CONNECTORS = [
      # Non-OAuth connectors
      Connectors::Native::Webhook,
      Connectors::Native::Database,
      Connectors::Native::Email,
      Connectors::Native::Slack,
      Connectors::Native::FileStorage,
      Connectors::Native::Apollo,
      Connectors::Native::Bitrix,
      Connectors::Native::Kommo,
      Connectors::Native::Whatsapp,
      # OAuth connectors — Google
      Connectors::Native::GoogleSheets,
      Connectors::Native::GoogleDrive,
      Connectors::Native::GoogleCalendar,
      Connectors::Native::Gmail,
      # OAuth connectors — other
      Connectors::Native::SlackOauth,
      Connectors::Native::GithubOauth,
      Connectors::Native::Hubspot,
      Connectors::Native::MicrosoftOutlook,
      Connectors::Native::Notion,
      Connectors::Native::JiraCloud,
      Connectors::Native::Airtable,
      Connectors::Native::StripeConnect,
      # Batch 2 — high-demand connectors
      Connectors::Native::Twilio,
      Connectors::Native::Sendgrid,
      Connectors::Native::Telegram,
      Connectors::Native::Shopify,
      Connectors::Native::Zendesk,
      # Batch 3 — CRM, marketing, productivity
      Connectors::Native::Pipedrive,
      Connectors::Native::Mailchimp,
      Connectors::Native::Intercom,
      Connectors::Native::Asana,
      Connectors::Native::Discord,
      # Batch 4 — productivity, support, forms, scheduling
      Connectors::Native::Monday,
      Connectors::Native::Freshdesk,
      Connectors::Native::Typeform,
      Connectors::Native::Calendly,
      Connectors::Native::Trello,
      # Batch 5 — developer tools, accounting, project management
      Connectors::Native::Gitlab,
      Connectors::Native::Sentry,
      Connectors::Native::Quickbooks,
      Connectors::Native::Linear,
      Connectors::Native::Clickup
      Connectors::Native::Salesforce
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
