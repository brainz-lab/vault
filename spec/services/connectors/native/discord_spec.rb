# frozen_string_literal: true

require "rails_helper"

RSpec.describe Connectors::Native::Discord, type: :service do
  let(:credentials) { { bot_token: "Bot.test.token", webhook_url: "https://discord.com/api/webhooks/123/abc", default_channel_id: "ch123" } }
  let(:connector) { described_class.new(credentials) }
  let(:api_base) { "https://discord.com/api/v10" }

  it_behaves_like "a native connector"

  describe "#execute send_message" do
    it "sends a bot message" do
      stub_json_post("#{api_base}/channels/ch123/messages",
        body: { id: "msg1", channel_id: "ch123" })

      result = connector.execute("send_message", content: "Hello!")
      expect(result[:success]).to be true
      expect(result[:id]).to eq("msg1")
    end

    it "raises error without bot_token" do
      no_bot = described_class.new({ webhook_url: "https://x" })
      expect { no_bot.execute("send_message", content: "test") }
        .to raise_error(Connectors::AuthenticationError, /bot_token/)
    end
  end

  describe "#execute send_embed" do
    it "sends an embed" do
      stub_json_post("#{api_base}/channels/ch123/messages",
        body: { id: "msg2", channel_id: "ch123" })

      result = connector.execute("send_embed", title: "Alert", description: "Something happened", color: 5814783)
      expect(result[:success]).to be true
    end
  end

  describe "#execute send_webhook" do
    it "sends a webhook message" do
      stub_request(:post, "https://discord.com/api/webhooks/123/abc")
        .to_return(status: 204, body: "")

      result = connector.execute("send_webhook", content: "Notification!")
      expect(result[:success]).to be true
    end
  end

  describe "#execute list_channels" do
    it "returns server channels" do
      stub_json_get("#{api_base}/guilds/g1/channels",
        body: [
          { id: "ch1", name: "general", type: 0, position: 0, topic: "General chat" },
          { id: "ch2", name: "voice", type: 2, position: 1, topic: nil },
          { id: "ch3", name: "category", type: 4, position: 0, topic: nil }
        ])

      result = connector.execute("list_channels", guild_id: "g1")
      expect(result[:channels].size).to eq(2) # excludes category type 4
      expect(result[:channels].first[:name]).to eq("general")
    end
  end

  describe "#execute get_messages" do
    it "returns messages" do
      stub_json_get("#{api_base}/channels/ch1/messages",
        body: [ { id: "m1", content: "hello", author: { username: "bob" }, timestamp: "2026-01-01", type: 0 } ])

      result = connector.execute("get_messages", channel_id: "ch1")
      expect(result[:messages].first[:content]).to eq("hello")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_json_post("#{api_base}/channels/ch123/messages",
        body: { message: "401: Unauthorized" }, status: 401)

      expect { connector.execute("send_message", content: "test") }
        .to raise_error(Connectors::AuthenticationError, /Discord/)
    end

    it "raises RateLimitError on 429" do
      stub_json_post("#{api_base}/channels/ch123/messages",
        body: { message: "Rate limited", retry_after: 5 }, status: 429)

      expect { connector.execute("send_message", content: "test") }
        .to raise_error(Connectors::RateLimitError)
    end
  end
end
