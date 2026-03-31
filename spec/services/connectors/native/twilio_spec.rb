# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Twilio, type: :service do
  let(:credentials) { { account_sid: "AC1234567890", auth_token: "test_token", from_number: "+15551234567" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.twilio.com/2010-04-01/Accounts/AC1234567890" }

  it_behaves_like "a native connector"

  describe "#execute send_sms" do
    it "sends an SMS and returns sid" do
      stub_json_post("#{api_base}/Messages.json",
        body: { sid: "SM123", status: "queued", to: "+15559876543", from: "+15551234567" })

      result = connector.execute("send_sms", to: "+15559876543", body: "Hello")
      expect(result[:success]).to be true
      expect(result[:sid]).to eq("SM123")
      expect(result[:status]).to eq("queued")
    end

    it "includes media_url for MMS" do
      stub_request(:post, "#{api_base}/Messages.json")
        .with(body: hash_including("MediaUrl" => "https://example.com/img.jpg"))
        .to_return(status: 200, body: { sid: "MM123", status: "queued", to: "+1", from: "+1" }.to_json)

      result = connector.execute("send_sms", to: "+1", body: "pic", media_url: "https://example.com/img.jpg")
      expect(result[:success]).to be true
    end
  end

  describe "#execute make_call" do
    it "initiates a call with TwiML" do
      stub_json_post("#{api_base}/Calls.json",
        body: { sid: "CA123", status: "queued", to: "+15559876543", from: "+15551234567" })

      result = connector.execute("make_call", to: "+15559876543", twiml: "<Say>Hello</Say>")
      expect(result[:success]).to be true
      expect(result[:sid]).to eq("CA123")
    end

    it "raises error without twiml or url" do
      expect { connector.execute("make_call", to: "+1") }
        .to raise_error(Connectors::Error, /twiml.*url/i)
    end
  end

  describe "#execute list_messages" do
    it "returns messages" do
      stub_json_get("#{api_base}/Messages.json",
        body: { messages: [ { sid: "SM1", to: "+1", from: "+2", body: "hi", status: "delivered", date_sent: "2026-01-01" } ] })

      result = connector.execute("list_messages")
      expect(result[:messages]).to be_an(Array)
      expect(result[:messages].first[:sid]).to eq("SM1")
    end
  end

  describe "#execute get_message" do
    it "returns message details" do
      stub_json_get("#{api_base}/Messages/SM123.json",
        body: { sid: "SM123", to: "+1", from: "+2", body: "hello", status: "delivered", date_sent: "2026-01-01", price: "-0.0075" })

      result = connector.execute("get_message", message_sid: "SM123")
      expect(result[:sid]).to eq("SM123")
      expect(result[:price]).to eq("-0.0075")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_post("#{api_base}/Messages.json", body: { message: "Unauthorized" }, status: 401)

      expect { connector.execute("send_sms", to: "+1", body: "test") }
        .to raise_error(Connectors::AuthenticationError, /Twilio/)
    end

    it "raises RateLimitError on 429" do
      stub_json_post("#{api_base}/Messages.json", body: { message: "Too many requests" }, status: 429)

      expect { connector.execute("send_sms", to: "+1", body: "test") }
        .to raise_error(Connectors::RateLimitError)
    end
  end
end
