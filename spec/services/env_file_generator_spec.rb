require "rails_helper"

RSpec.describe EnvFileGenerator do
  before do
    @project = create(:project, name: "Generator Test Project")
    @environment = create(:secret_environment, project: @project, name: "Development", slug: "development")
    @generator = described_class.new(@environment)
  end

  describe "#generate with :dotenv format" do
    it "returns key=value lines" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "DATABASE_URL" => "postgres://localhost",
        "REDIS_URL" => "redis://localhost"
      })

      result = @generator.generate(format: :dotenv)

      expect(result).to include("DATABASE_URL=postgres://localhost")
      expect(result).to include("REDIS_URL=redis://localhost")
    end

    it "escapes values with spaces" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "SECRET_WITH_SPACES" => "value with spaces"
      })

      result = @generator.generate(format: :dotenv)
      expect(result).to include('"value with spaces"')
    end

    it "escapes quotes" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "SECRET_WITH_QUOTES" => 'value with "quotes"'
      })

      result = @generator.generate(format: :dotenv)
      expect(result).to include('\\"')
    end

    it "escapes newlines" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "MULTILINE" => "line1\nline2"
      })

      result = @generator.generate(format: :dotenv)
      expect(result).to include("\\n")
    end

    it "handles empty values" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "EMPTY" => ""
      })

      result = @generator.generate(format: :dotenv)
      expect(result).to include('EMPTY=""')
    end
  end

  describe "#generate with :json format" do
    it "returns valid JSON" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "DATABASE_URL" => "postgres://localhost"
      })

      result = @generator.generate(format: :json)
      parsed = JSON.parse(result)
      expect(parsed["DATABASE_URL"]).to eq("postgres://localhost")
    end
  end

  describe "#generate with :yaml format" do
    it "returns valid YAML" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "DATABASE_URL" => "postgres://localhost"
      })

      result = @generator.generate(format: :yaml)
      parsed = YAML.safe_load(result)
      expect(parsed["DATABASE_URL"]).to eq("postgres://localhost")
    end
  end

  describe "#generate with :shell format" do
    it "returns export statements" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "DATABASE_URL" => "postgres://localhost"
      })

      result = @generator.generate(format: :shell)
      expect(result).to include("export DATABASE_URL=")
    end

    it "escapes shell characters" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({
        "SECRET" => "value with $pecial chars"
      })

      result = @generator.generate(format: :shell)
      # Shellwords.escape should escape the $ character
      expect(result).to include("\\$pecial").or include("'")
    end
  end

  describe "#generate with unknown format" do
    it "raises ArgumentError" do
      allow_any_instance_of(SecretResolver).to receive(:resolve_all).and_return({})

      expect {
        @generator.generate(format: :invalid)
      }.to raise_error(ArgumentError)
    end
  end
end
