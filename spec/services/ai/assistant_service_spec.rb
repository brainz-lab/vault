require "rails_helper"

RSpec.describe Ai::AssistantService do
  let(:project) { create(:project) }
  let(:chat) { AssistantChat.create!(user_id: "test_user") }
  let(:service) { described_class.new(chat, project: project) }

  describe "AI usage tracking" do
    let(:claude_response) do
      {
        "id" => "msg_abc123",
        "model" => "claude-sonnet-4-20250514",
        "content" => [ { "type" => "text", "text" => "Hello!" } ],
        "usage" => {
          "input_tokens" => 100,
          "output_tokens" => 50,
          "cache_creation_input_tokens" => 20,
          "cache_read_input_tokens" => 30
        }
      }
    end

    before do
      allow(service).to receive(:call_claude).and_return(claude_response)
    end

    it "accumulates token counts from Claude responses" do
      service.send_message("Hello")

      expect(service.instance_variable_get(:@ai_total_input_tokens)).to eq(100)
      expect(service.instance_variable_get(:@ai_total_output_tokens)).to eq(50)
      expect(service.instance_variable_get(:@ai_total_cache_creation_tokens)).to eq(20)
      expect(service.instance_variable_get(:@ai_total_cache_read_tokens)).to eq(30)
    end

    it "accumulates tokens across multiple tool-use rounds" do
      tool_response = {
        "id" => "msg_round1",
        "model" => "claude-sonnet-4-20250514",
        "content" => [
          { "type" => "text", "text" => "Let me check." },
          { "type" => "tool_use", "id" => "tu_1", "name" => "vault_list_secrets", "input" => {} }
        ],
        "usage" => {
          "input_tokens" => 80,
          "output_tokens" => 40,
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 50
        }
      }

      final_response = {
        "id" => "msg_round2",
        "model" => "claude-sonnet-4-20250514",
        "content" => [ { "type" => "text", "text" => "Here are your secrets." } ],
        "usage" => {
          "input_tokens" => 200,
          "output_tokens" => 60,
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 100
        }
      }

      allow(service).to receive(:call_claude).and_return(tool_response, final_response)
      allow(service).to receive(:execute_tool).and_return({ secrets: [] })

      service.send_message("List my secrets")

      expect(service.instance_variable_get(:@ai_total_input_tokens)).to eq(280)
      expect(service.instance_variable_get(:@ai_total_output_tokens)).to eq(100)
      expect(service.instance_variable_get(:@ai_total_cache_read_tokens)).to eq(150)
    end

    it "attaches metrics to CurrentTransaction via gem adapter" do
      tx = { type: "request", service: "vault" }
      allow(BrainzLab::PlatformClient::CurrentTransaction).to receive(:get).and_return(tx)

      service.send_message("Hello")

      expect(tx[:ai_provider]).to eq("anthropic")
      expect(tx[:ai_model]).to eq("claude-sonnet-4-20250514")
      expect(tx[:ai_input_tokens]).to eq(100)
      expect(tx[:ai_output_tokens]).to eq(50)
      expect(tx[:ai_cache_creation_tokens]).to eq(20)
      expect(tx[:ai_cache_read_tokens]).to eq(30)
    end

    it "does not fail when CurrentTransaction is nil" do
      allow(BrainzLab::PlatformClient::CurrentTransaction).to receive(:get).and_return(nil)

      expect { service.send_message("Hello") }.not_to raise_error
    end

    it "reports metrics even on error" do
      allow(service).to receive(:call_claude).and_raise(RuntimeError, "API error")

      tx = { type: "request", service: "vault" }
      allow(BrainzLab::PlatformClient::CurrentTransaction).to receive(:get).and_return(tx)

      result = service.send_message("Hello")

      expect(result[:content]).to include("error")
      # No tokens accumulated since call_claude raised before returning
      expect(tx).not_to have_key(:ai_provider)
    end

    it "handles responses without cache tokens" do
      response_no_cache = {
        "id" => "msg_no_cache",
        "model" => "claude-sonnet-4-20250514",
        "content" => [ { "type" => "text", "text" => "Hi!" } ],
        "usage" => {
          "input_tokens" => 50,
          "output_tokens" => 25
        }
      }

      allow(service).to receive(:call_claude).and_return(response_no_cache)

      tx = { type: "request", service: "vault" }
      allow(BrainzLab::PlatformClient::CurrentTransaction).to receive(:get).and_return(tx)

      service.send_message("Hi")

      expect(tx[:ai_input_tokens]).to eq(50)
      expect(tx[:ai_output_tokens]).to eq(25)
      expect(tx).not_to have_key(:ai_cache_creation_tokens)
      expect(tx).not_to have_key(:ai_cache_read_tokens)
    end
  end
end
