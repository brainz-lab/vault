# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Mailchimp, type: :service do
  let(:credentials) { { api_key: "abc123-us21" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://us21.api.mailchimp.com/3.0" }

  it_behaves_like "a native connector"

  describe "#execute list_audiences" do
    it "returns audiences" do
      stub_json_get("#{api_base}/lists",
        body: { lists: [{ id: "l1", name: "Newsletter", stats: { member_count: 500, unsubscribe_count: 10, campaign_count: 20 } }] })

      result = connector.execute("list_audiences")
      expect(result[:audiences].first[:name]).to eq("Newsletter")
      expect(result[:audiences].first[:member_count]).to eq(500)
    end
  end

  describe "#execute list_members" do
    it "returns members" do
      stub_json_get("#{api_base}/lists/l1/members",
        body: { members: [{ id: "m1", email_address: "a@b.com", status: "subscribed",
          merge_fields: { FNAME: "Alice", LNAME: "B" }, tags: [{ name: "vip" }] }], total_items: 1 })

      result = connector.execute("list_members", list_id: "l1")
      expect(result[:members].first[:email]).to eq("a@b.com")
      expect(result[:total]).to eq(1)
    end
  end

  describe "#execute add_member" do
    it "adds/updates a member" do
      email_hash = Digest::MD5.hexdigest("new@example.com")
      stub_json_put("#{api_base}/lists/l1/members/#{email_hash}",
        body: { id: "m2", email_address: "new@example.com", status: "subscribed" })

      result = connector.execute("add_member", list_id: "l1", email: "new@example.com", first_name: "New")
      expect(result[:success]).to be true
      expect(result[:email]).to eq("new@example.com")
    end
  end

  describe "#execute list_campaigns" do
    it "returns campaigns" do
      stub_json_get("#{api_base}/campaigns",
        body: { campaigns: [{ id: "c1", type: "regular", status: "sent",
          settings: { subject_line: "Hello", title: "March Newsletter" }, emails_sent: 500, send_time: "2026-01-01" }] })

      result = connector.execute("list_campaigns")
      expect(result[:campaigns].first[:subject]).to eq("Hello")
    end
  end

  describe "#execute get_campaign_report" do
    it "returns report metrics" do
      stub_json_get("#{api_base}/reports/c1",
        body: { id: "c1", campaign_title: "Newsletter", subject_line: "Hello", emails_sent: 500,
          opens: { opens_total: 200, unique_opens: 150, open_rate: 0.3 },
          clicks: { clicks_total: 50, unique_clicks: 40, click_rate: 0.08 },
          unsubscribed: 2, bounces: { hard_bounces: 1 } })

      result = connector.execute("get_campaign_report", campaign_id: "c1")
      expect(result[:open_rate]).to eq(0.3)
      expect(result[:emails_sent]).to eq(500)
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_get("#{api_base}/lists",
        body: { title: "API Key Invalid", detail: "Your API key is invalid" }, status: 401)

      expect { connector.execute("list_audiences") }
        .to raise_error(Connectors::AuthenticationError, /Mailchimp/)
    end
  end
end
