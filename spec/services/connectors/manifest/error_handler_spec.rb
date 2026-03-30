require "rails_helper"

RSpec.describe Connectors::Manifest::ErrorHandler do
  describe "#should_retry?" do
    subject(:handler) { described_class.new({ "max_retries" => 2 }) }

    it "retries on 429" do
      expect(handler.should_retry?(429)).to be(true)
    end

    it "retries on 500" do
      expect(handler.should_retry?(500)).to be(true)
    end

    it "retries on 503" do
      expect(handler.should_retry?(503)).to be(true)
    end

    it "does not retry on 200" do
      expect(handler.should_retry?(200)).to be(false)
    end

    it "does not retry on 404" do
      expect(handler.should_retry?(404)).to be(false)
    end
  end

  describe "#with_retry" do
    it "retries up to max_retries on retryable errors" do
      handler = described_class.new({ "max_retries" => 2, "backoff_strategies" => [{ "type" => "ConstantBackoffStrategy", "backoff_time_in_seconds" => 0 }] })
      attempts = 0

      expect {
        handler.with_retry do
          attempts += 1
          raise Connectors::RateLimitError, "rate limited"
        end
      }.to raise_error(Connectors::RateLimitError)

      expect(attempts).to eq(3) # 1 initial + 2 retries
    end

    it "succeeds if retry works" do
      handler = described_class.new({ "max_retries" => 2, "backoff_strategies" => [{ "type" => "ConstantBackoffStrategy", "backoff_time_in_seconds" => 0 }] })
      attempts = 0

      result = handler.with_retry do
        attempts += 1
        raise Connectors::RateLimitError, "rate limited" if attempts < 2
        "success"
      end

      expect(result).to eq("success")
      expect(attempts).to eq(2)
    end
  end
end
