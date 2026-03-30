# Vault Native Connectors — Development Guide

## Overview

Vault provides a three-tier connector system for integrating with external services:

| Tier | Type | Count | Execution | Capabilities |
|------|------|-------|-----------|-------------|
| **1** | Native (Ruby) | 41 | In-process | Read + Write, full control |
| **2** | Airbyte (YAML) | ~350+ | Manifest interpreter | Read-only (sync streams) |
| **3** | Activepieces | ~400+ | External sidecar | Read + Write, depends on sidecar |

**Native connectors are preferred** for high-demand integrations because they offer:
- Bidirectional operations (read + write in one connector)
- Custom error handling per service
- No external dependencies (no Docker, no sidecar)
- Better performance (no HTTP overhead)

## Architecture

```
Connectors::Executor#execute
├── connector_type: "native"      → Connectors::Native::{Name}.new(credentials).execute(action, **params)
├── connector_type: "airbyte"     → Connectors::Manifest::Engine.new(yaml, credentials).execute(stream, limit:)
└── connector_type: "activepieces" → POST sidecar:3100/execute
```

### Key Files

| File | Purpose |
|------|---------|
| `app/services/connectors/native/base.rb` | Base class — all connectors inherit from this |
| `app/services/connectors/native_seeder.rb` | Registers native connectors in DB on seed |
| `app/services/connectors/executor.rb` | Routes execution to the correct handler |
| `app/services/connectors/error.rb` | Error hierarchy (AuthenticationError, RateLimitError, etc.) |
| `spec/support/connector_helpers.rb` | Shared RSpec examples and WebMock helpers |

## How to Add a New Native Connector

### Step 1: Create the connector class

```ruby
# app/services/connectors/native/my_service.rb
module Connectors
  module Native
    class MyService < Base
      def self.piece_name = "my-service"           # Unique identifier
      def self.display_name = "My Service"          # UI display name
      def self.description = "What it does"         # Short description
      def self.category = "crm"                     # Category (see list below)
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/my-service.svg"
      def self.auth_type = "SECRET_TEXT"             # See auth types below
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_key: { type: "string", description: "API Key", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: ["Step 1...", "Step 2..."],
          docs_url: "https://docs.myservice.com/api"
        }
      end

      def self.actions
        [
          {
            "name" => "list_items",              # snake_case, matches execute case
            "displayName" => "List Items",
            "description" => "List all items",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_items" then list_items(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def list_items(params)
        result = api_get("items", limit: (params[:limit] || 50).to_i)
        items = result["items"].map { |i| { id: i["id"], name: i["name"] } }
        { items: items, count: items.size }
      end

      # Standard HTTP helpers — follow this pattern
      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data["message"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "MyService: #{error}" if resp.status == 401
          raise Connectors::RateLimitError, "MyService rate limited" if resp.status == 429
          raise Connectors::Error, "MyService: #{error}"
        end
        data
      end

      def api_base = "https://api.myservice.com/v1"
      def api_key = credentials[:api_key]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
```

### Step 2: Register in NativeSeeder

```ruby
# app/services/connectors/native_seeder.rb
NATIVE_CONNECTORS = [
  # ... existing connectors ...
  Connectors::Native::MyService
].freeze
```

### Step 3: Add routing in Executor

```ruby
# app/services/connectors/executor.rb → native_runner_for
when "my-service" then Connectors::Native::MyService
```

### Step 4: Write tests

```ruby
# spec/services/connectors/native/my_service_spec.rb
require "rails_helper"

RSpec.describe Connectors::Native::MyService, type: :service do
  let(:credentials) { { api_key: "test_key" } }
  let(:connector) { described_class.new(credentials) }

  it_behaves_like "a native connector"

  describe "#execute list_items" do
    it "returns items" do
      stub_json_get("https://api.myservice.com/v1/items",
        body: { items: [{ id: "1", name: "Item 1" }] })

      result = connector.execute("list_items")
      expect(result[:items].first[:name]).to eq("Item 1")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("https://api.myservice.com/v1/items",
        body: { message: "Unauthorized" }, status: 401)

      expect { connector.execute("list_items") }
        .to raise_error(Connectors::AuthenticationError)
    end
  end
end
```

### Step 5: Seed the database

```bash
VAULT_MASTER_KEY=... bin/rails runner "Connectors::NativeSeeder.new.seed!"
```

## Conventions

### Auth Types

| Type | When to use | Example |
|------|-------------|---------|
| `SECRET_TEXT` | Single API key/token | SendGrid, Telegram, Asana |
| `BASIC` | Username + password/token | Twilio (SID + Auth Token) |
| `OAUTH2` | OAuth 2.0 flow | (use for future OAuth connectors) |
| `CUSTOM_AUTH` | Multiple fields or mixed auth | Shopify (store + token), Zendesk (subdomain + email + token) |
| `NONE` | No auth needed | Webhook |

### Categories

`communication`, `crm`, `productivity`, `developer`, `support`, `project_management`,
`marketing`, `ecommerce`, `accounting`, `forms`, `scheduling`, `automation`, `data`,
`storage`, `sales`, `payment_processing`

### Error Handling

Always map HTTP status codes:
- **401/403** → `Connectors::AuthenticationError`
- **429** → `Connectors::RateLimitError`
- **408/timeout** → `Connectors::TimeoutError`
- **Everything else** → `Connectors::Error`

### Action Design

- **Read actions** return `{ items: [...], count: N }` or `{ item: {...} }`
- **Write actions** return `{ success: true, id: "...", ... }`
- Use **keyword params** (`**params`) — all values arrive as symbols
- Parse JSON strings for complex params: `JSON.parse(value) rescue value`
- Default reasonable limits (20-50) with max caps

### GraphQL APIs (Monday.com, Linear)

For services with GraphQL APIs, use a `graphql(query)` helper method instead of REST.
Escape user input with a `escape_gql(str)` helper.

## Current Native Connectors (41)

### Communication (10)
webhook, email, slack, slack-oauth, gmail, whatsapp, twilio, sendgrid, telegram, discord

### CRM (4)
hubspot, apollo, bitrix, kommo, pipedrive

### Productivity (9)
google-sheets, google-drive, google-calendar, notion, airtable, asana, monday, trello, clickup

### Support (3)
zendesk, intercom, freshdesk

### Developer (3)
github, gitlab, sentry

### Project Management (2)
jira-cloud, linear

### Other (10)
stripe (payment), shopify (ecommerce), mailchimp (marketing), typeform (forms),
calendly (scheduling), quickbooks (accounting), database (data), file_storage (storage),
microsoft-outlook (communication)

## Next Priorities (Future Cycles)

### Cycle 2 — Finance & Analytics
| Connector | Category | API Style | Priority |
|-----------|----------|-----------|----------|
| **Xero** | accounting | REST + OAuth 2.0 | High |
| **Chargebee** | billing | REST + API Key | High |
| **Amplitude** | analytics | REST + API Key | Medium |
| **Mixpanel** | analytics | REST + API Key | Medium |
| **Segment** | analytics | REST + API Key | Medium |

### Cycle 3 — DevOps & Monitoring
| Connector | Category | API Style | Priority |
|-----------|----------|-----------|----------|
| **Datadog** | monitoring | REST + API Key | High |
| **PagerDuty** | incident | REST + API Key | High |
| **New Relic** | monitoring | REST + API Key | Medium |
| **Opsgenie** | incident | REST + API Key | Medium |

### Cycle 4 — Collaboration & Social
| Connector | Category | API Style | Priority |
|-----------|----------|-----------|----------|
| **Confluence** | knowledge | REST + Bearer | High |
| **Basecamp** | productivity | REST + OAuth 2.0 | Medium |
| **Instagram** | social | REST + OAuth 2.0 | Medium |
| **Twitter/X** | social | REST + OAuth 2.0 | Low |
| **LinkedIn** | social | REST + OAuth 2.0 | Low |

### Cycle 5 — Data & Cloud
| Connector | Category | API Style | Priority |
|-----------|----------|-----------|----------|
| **AWS S3** | storage | SDK + IAM | High |
| **Google BigQuery** | data | REST + Service Account | Medium |
| **Snowflake** | data | REST + Key Pair | Medium |
| **Elasticsearch** | search | REST + API Key | Medium |

## Airbyte Manifest Interpreter

For services that don't need write operations, the Airbyte manifest interpreter
(`Connectors::Manifest::Engine`) provides read-only access to 350+ sources
by parsing their YAML manifests natively in Ruby.

**When to use manifest vs native:**
- **Use manifest** when: read-only sync is sufficient, the service isn't high-demand
- **Use native** when: you need write operations, custom error handling, or the service is heavily used

The `AirbyteSeeder` automatically fetches manifests from the Airbyte OSS registry
for `manifest-only` and `low-code` connectors.

## Running Tests

```bash
# All connector specs
bundle exec rspec spec/services/connectors/native/

# Single connector
bundle exec rspec spec/services/connectors/native/twilio_spec.rb

# With verbose output
bundle exec rspec spec/services/connectors/native/ --format documentation
```

## Reverse-Engineering Airbyte Connectors

When adding a new native connector, Airbyte's open-source manifests are a great reference:

1. Find the connector at `https://github.com/airbytehq/airbyte/tree/master/airbyte-integrations/connectors/source-{name}`
2. Read `manifest.yaml` for API structure: base URL, auth, pagination, streams
3. Check `metadata.yaml` for docs URL and support level
4. Implement as native Ruby following our patterns (bidirectional, error handling)

Key Airbyte patterns to adapt:
- **Streams** → **Actions** (each Airbyte stream becomes a `list_*` action)
- **Check connection** → Include in auth validation
- **Pagination** → Handle internally per action
- **Add write operations** that Airbyte doesn't have (create, update, delete)
