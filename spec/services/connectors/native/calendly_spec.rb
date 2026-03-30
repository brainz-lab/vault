# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Calendly, type: :service do
  let(:credentials) { { access_token: "cal_test_token" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.calendly.com" }
  let(:user_uri) { "https://api.calendly.com/users/U123" }
  let(:org_uri) { "https://api.calendly.com/organizations/O123" }

  before do
    stub_json_get("#{api_base}/users/me",
      body: { resource: { uri: user_uri, current_organization: org_uri } })
  end

  it_behaves_like "a native connector"

  describe "#execute list_events" do
    it "returns events" do
      stub_json_get("#{api_base}/scheduled_events",
        body: { collection: [{ uri: "#{api_base}/scheduled_events/E1", name: "30 min meeting", status: "active",
          start_time: "2026-04-01T10:00:00Z", end_time: "2026-04-01T10:30:00Z", event_type: "one_on_one",
          location: { location: "Zoom" }, invitees_counter: { total: 1 }, created_at: "2026-01-01" }] })

      result = connector.execute("list_events")
      expect(result[:events].first[:name]).to eq("30 min meeting")
    end
  end

  describe "#execute list_invitees" do
    it "returns invitees for an event" do
      stub_json_get("#{api_base}/scheduled_events/E1/invitees",
        body: { collection: [{ uri: "inv1", name: "Bob", email: "bob@test.com", status: "active",
          timezone: "America/New_York", created_at: "2026-01-01", questions_and_answers: [] }] })

      result = connector.execute("list_invitees", event_uuid: "E1")
      expect(result[:invitees].first[:name]).to eq("Bob")
    end
  end

  describe "#execute list_event_types" do
    it "returns event types" do
      stub_json_get("#{api_base}/event_types",
        body: { collection: [{ uri: "et1", name: "30min", slug: "30min", active: true,
          duration: 30, kind: "solo", scheduling_url: "https://calendly.com/user/30min" }] })

      result = connector.execute("list_event_types")
      expect(result[:event_types].first[:name]).to eq("30min")
    end
  end

  describe "#execute cancel_event" do
    it "cancels an event" do
      stub_json_post("#{api_base}/scheduled_events/E1/cancellation", body: {})

      result = connector.execute("cancel_event", event_uuid: "E1", reason: "Rescheduling")
      expect(result[:success]).to be true
    end
  end
end
