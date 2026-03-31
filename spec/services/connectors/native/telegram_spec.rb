# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Telegram, type: :service do
  let(:credentials) { { bot_token: "123456:ABC-DEF", default_chat_id: "987654321" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://api.telegram.org/bot123456:ABC-DEF" }

  it_behaves_like "a native connector"

  describe "#execute send_message" do
    it "sends a message and returns message_id" do
      stub_json_post("#{api_base}/sendMessage",
        body: { ok: true, result: { message_id: 42, chat: { id: 987654321 }, date: 1234567890 } })

      result = connector.execute("send_message", text: "Hello!")
      expect(result[:success]).to be true
      expect(result[:message_id]).to eq(42)
    end

    it "uses default_chat_id when chat_id not provided" do
      stub_json_post("#{api_base}/sendMessage",
        body: { ok: true, result: { message_id: 1, chat: { id: 987654321 }, date: 1 } })

      result = connector.execute("send_message", text: "test")
      expect(result[:message_id]).to eq(1)
    end

    it "raises error without chat_id and no default" do
      no_default = described_class.new({ bot_token: "123:ABC" })
      expect { no_default.execute("send_message", text: "test") }
        .to raise_error(Connectors::Error, /chat_id/)
    end
  end

  describe "#execute send_photo" do
    it "sends a photo" do
      stub_json_post("#{api_base}/sendPhoto",
        body: { ok: true, result: { message_id: 43, chat: { id: 987654321 } } })

      result = connector.execute("send_photo", photo: "https://example.com/img.jpg")
      expect(result[:success]).to be true
    end
  end

  describe "#execute send_document" do
    it "sends a document" do
      stub_json_post("#{api_base}/sendDocument",
        body: { ok: true, result: { message_id: 44, chat: { id: 987654321 } } })

      result = connector.execute("send_document", document: "https://example.com/file.pdf")
      expect(result[:success]).to be true
    end
  end

  describe "#execute get_updates" do
    it "returns recent updates" do
      stub_json_post("#{api_base}/getUpdates",
        body: { ok: true, result: [
          { update_id: 1, message: { message_id: 10, chat: { id: 1, type: "private" }, from: { username: "bob" }, text: "hi", date: 1 } }
        ] })

      result = connector.execute("get_updates")
      expect(result[:updates]).to be_an(Array)
      expect(result[:updates].first[:text]).to eq("hi")
    end
  end

  describe "#execute set_webhook" do
    it "sets webhook URL" do
      stub_json_post("#{api_base}/setWebhook",
        body: { ok: true, result: true, description: "Webhook was set" })

      result = connector.execute("set_webhook", url: "https://example.com/webhook")
      expect(result[:success]).to be true
    end
  end

  describe "#execute get_chat" do
    it "returns chat info" do
      stub_json_post("#{api_base}/getChat",
        body: { ok: true, result: { id: 123, type: "group", title: "My Group", username: nil, description: "A group" } })

      result = connector.execute("get_chat", chat_id: "123")
      expect(result[:title]).to eq("My Group")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_post("#{api_base}/sendMessage",
        body: { ok: false, error_code: 401, description: "Unauthorized" })

      expect { connector.execute("send_message", text: "test") }
        .to raise_error(Connectors::AuthenticationError)
    end

    it "raises RateLimitError on 429" do
      stub_json_post("#{api_base}/sendMessage",
        body: { ok: false, error_code: 429, description: "Too Many Requests" })

      expect { connector.execute("send_message", text: "test") }
        .to raise_error(Connectors::RateLimitError)
    end
  end
end
