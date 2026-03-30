require "rails_helper"

RSpec.describe Connectors::Manifest::HttpRequester do
  let(:interpolator) { Connectors::Manifest::Interpolator.new(config: { "token" => "test" }) }
  let(:authenticator) { Connectors::Manifest::Authenticators::NoAuth.new({}, {}, interpolator: interpolator) }
  let(:error_handler) { Connectors::Manifest::ErrorHandler.new({ "max_retries" => 0 }) }

  def build_requester(url_base:, path:, handler: error_handler)
    config = { "url_base" => url_base, "path" => path, "http_method" => "GET" }
    described_class.new(config, interpolator: interpolator, authenticator: authenticator, error_handler: handler)
  end

  describe "SSRF prevention" do
    it "blocks HTTP (non-HTTPS) URLs" do
      requester = build_requester(url_base: "http://api.example.com", path: "/data")
      expect { requester.fetch }.to raise_error(Connectors::SecurityError, /Only HTTPS/)
    end

    it "blocks localhost" do
      requester = build_requester(url_base: "https://localhost:3000", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("127.0.0.1")
      expect { requester.fetch }.to raise_error(Connectors::SecurityError, /SSRF blocked/)
    end

    it "blocks 10.x private IPs" do
      requester = build_requester(url_base: "https://internal.corp.com", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("10.0.0.1")
      expect { requester.fetch }.to raise_error(Connectors::SecurityError, /SSRF blocked/)
    end

    it "blocks 172.16-31.x private IPs" do
      requester = build_requester(url_base: "https://internal.corp.com", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("172.16.0.1")
      expect { requester.fetch }.to raise_error(Connectors::SecurityError, /SSRF blocked/)
    end

    it "blocks 192.168.x private IPs" do
      requester = build_requester(url_base: "https://internal.corp.com", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("192.168.1.1")
      expect { requester.fetch }.to raise_error(Connectors::SecurityError, /SSRF blocked/)
    end
  end

  describe "successful requests" do
    it "fetches and parses JSON from valid HTTPS URLs" do
      stub_request(:get, "https://api.example.com/data")
        .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

      requester = build_requester(url_base: "https://api.example.com", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("93.184.216.34")

      result = requester.fetch
      expect(result["ok"]).to be(true)
    end
  end

  describe "error handling" do
    it "raises RateLimitError on HTTP 429" do
      stub_request(:get, "https://api.example.com/data")
        .to_return(status: 429, body: "Rate limited")

      requester = build_requester(url_base: "https://api.example.com", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("93.184.216.34")

      expect { requester.fetch }.to raise_error(Connectors::RateLimitError)
    end

    it "raises Error on HTTP 404" do
      stub_request(:get, "https://api.example.com/data")
        .to_return(status: 404, body: '{"error":"not found"}', headers: { "Content-Type" => "application/json" })

      requester = build_requester(url_base: "https://api.example.com", path: "/data")
      allow(Resolv).to receive(:getaddress).and_return("93.184.216.34")

      expect { requester.fetch }.to raise_error(Connectors::Error, /HTTP 404/)
    end
  end
end
