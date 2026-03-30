require "rails_helper"

RSpec.describe Connectors::Manifest::Engine do
  let(:simple_manifest) do
    <<~YAML
      version: "0.1.0"
      definitions:
        base_requester:
          type: HttpRequester
          url_base: "https://pokeapi.co/api/v2"
          http_method: GET
        pokemon_stream:
          type: DeclarativeStream
          name: pokemon
          retriever:
            type: SimpleRetriever
            requester:
              $ref: "#/definitions/base_requester"
              path: "/pokemon"
              request_parameters:
                limit: "20"
            record_selector:
              extractor:
                type: DpathExtractor
                field_path: ["results"]
      streams:
        - $ref: "#/definitions/pokemon_stream"
      check:
        stream_names:
          - pokemon
    YAML
  end

  let(:api_key_manifest) do
    <<~YAML
      version: "0.1.0"
      streams:
        - name: contacts
          retriever:
            requester:
              type: HttpRequester
              url_base: "https://api.example.com"
              path: "/v1/contacts"
              http_method: GET
              authenticator:
                type: ApiKeyAuthenticator
                api_token: "{{ config['api_key'] }}"
                inject_into:
                  type: RequestOption
                  field_name: "X-Api-Key"
                  inject_into: header
            record_selector:
              extractor:
                type: DpathExtractor
                field_path: ["data"]
      check:
        stream_names:
          - contacts
    YAML
  end

  let(:paginated_manifest) do
    <<~YAML
      version: "0.1.0"
      streams:
        - name: items
          retriever:
            requester:
              type: HttpRequester
              url_base: "https://api.example.com"
              path: "/items"
              http_method: GET
              authenticator:
                type: BearerAuthenticator
                api_token: "{{ config['token'] }}"
            record_selector:
              extractor:
                type: DpathExtractor
                field_path: ["items"]
            paginator:
              type: DefaultPaginator
              pagination_strategy:
                type: OffsetIncrement
                page_size: 2
              page_size_option:
                type: RequestOption
                field_name: "limit"
                inject_into: request_parameter
              page_token_option:
                type: RequestOption
                field_name: "offset"
                inject_into: request_parameter
      check:
        stream_names:
          - items
    YAML
  end

  describe "#discover_streams" do
    it "returns stream names and schemas" do
      engine = described_class.new(simple_manifest, {})
      streams = engine.discover_streams

      expect(streams.length).to eq(1)
      expect(streams.first[:name]).to eq("pokemon")
    end
  end

  describe "#stream_names" do
    it "returns list of names" do
      engine = described_class.new(simple_manifest, {})
      expect(engine.stream_names).to eq(["pokemon"])
    end
  end

  describe "#execute" do
    it "fetches records from a stream" do
      stub_request(:get, /pokeapi\.co/)
        .to_return(
          status: 200,
          body: { results: [{ name: "bulbasaur" }, { name: "charmander" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      allow(Resolv).to receive(:getaddress).and_return("104.16.0.1")

      engine = described_class.new(simple_manifest, {})
      records = engine.execute("pokemon")

      expect(records.length).to eq(2)
      expect(records.first["name"]).to eq("bulbasaur")
    end

    it "applies API key authentication" do
      stub_request(:get, "https://api.example.com/v1/contacts")
        .with(headers: { "X-Api-Key" => "my-secret-key" })
        .to_return(
          status: 200,
          body: { data: [{ id: 1, name: "Alice" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      allow(Resolv).to receive(:getaddress).and_return("93.184.216.34")

      engine = described_class.new(api_key_manifest, { "api_key" => "my-secret-key" })
      records = engine.execute("contacts")

      expect(records.length).to eq(1)
      expect(records.first["name"]).to eq("Alice")
    end

    it "handles offset pagination" do
      stub_request(:get, "https://api.example.com/items")
        .with(query: hash_including("limit" => "2", "offset" => "0"))
        .to_return(
          status: 200,
          body: { items: [{ id: 1 }, { id: 2 }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, "https://api.example.com/items")
        .with(query: hash_including("limit" => "2", "offset" => "2"))
        .to_return(
          status: 200,
          body: { items: [{ id: 3 }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      allow(Resolv).to receive(:getaddress).and_return("93.184.216.34")

      engine = described_class.new(paginated_manifest, { "token" => "test-token" })
      records = engine.execute("items")

      expect(records.length).to eq(3)
      expect(records.map { |r| r["id"] }).to eq([1, 2, 3])
    end

    it "raises ActionNotFoundError for unknown stream" do
      engine = described_class.new(simple_manifest, {})
      expect { engine.execute("nonexistent") }.to raise_error(Connectors::ActionNotFoundError)
    end
  end

  describe "#check_connection" do
    it "returns true when check stream succeeds" do
      stub_request(:get, /pokeapi\.co/)
        .to_return(
          status: 200,
          body: { results: [{ name: "pikachu" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      allow(Resolv).to receive(:getaddress).and_return("104.16.0.1")

      engine = described_class.new(simple_manifest, {})
      expect(engine.check_connection).to be(true)
    end

    it "returns false on failure" do
      stub_request(:get, /pokeapi\.co/).to_return(status: 401, body: "Unauthorized")
      allow(Resolv).to receive(:getaddress).and_return("104.16.0.1")

      engine = described_class.new(simple_manifest, {})
      expect(engine.check_connection).to be(false)
    end
  end
end
