# frozen_string_literal: true

require "test_helper"

class EnvFileGeneratorTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @environment = secret_environments(:acme_development)
    @generator = EnvFileGenerator.new(@environment)
  end

  # ===========================================
  # #generate with :dotenv format
  # ===========================================

  test "generate with dotenv format returns key=value lines" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "DATABASE_URL" => "postgres://localhost",
      "REDIS_URL" => "redis://localhost"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :dotenv)

      assert result.include?("DATABASE_URL=postgres://localhost")
      assert result.include?("REDIS_URL=redis://localhost")
    end
  end

  test "generate with dotenv escapes special characters" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "SECRET_WITH_SPACES" => "value with spaces"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :dotenv)
      assert result.include?('"value with spaces"')
    end
  end

  test "generate with dotenv escapes quotes" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "SECRET_WITH_QUOTES" => 'value with "quotes"'
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :dotenv)
      assert result.include?('\\"')
    end
  end

  test "generate with dotenv escapes newlines" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "MULTILINE" => "line1\nline2"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :dotenv)
      assert result.include?("\\n")
    end
  end

  test "generate with dotenv handles empty values" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "EMPTY" => ""
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :dotenv)
      assert result.include?('EMPTY=""')
    end
  end

  # ===========================================
  # #generate with :json format
  # ===========================================

  test "generate with json format returns valid JSON" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "DATABASE_URL" => "postgres://localhost"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :json)
      parsed = JSON.parse(result)
      assert_equal "postgres://localhost", parsed["DATABASE_URL"]
    end
  end

  # ===========================================
  # #generate with :yaml format
  # ===========================================

  test "generate with yaml format returns valid YAML" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "DATABASE_URL" => "postgres://localhost"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :yaml)
      parsed = YAML.safe_load(result)
      assert_equal "postgres://localhost", parsed["DATABASE_URL"]
    end
  end

  # ===========================================
  # #generate with :shell format
  # ===========================================

  test "generate with shell format returns export statements" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "DATABASE_URL" => "postgres://localhost"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :shell)
      assert result.include?("export DATABASE_URL=")
    end
  end

  test "generate with shell escapes shell characters" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {
      "SECRET" => "value with $pecial chars"
    }

    SecretResolver.stub :new, mock_resolver do
      result = @generator.generate(format: :shell)
      # Shellwords.escape should escape the $ character
      assert result.include?("\\$pecial") || result.include?("'")
    end
  end

  # ===========================================
  # Invalid format
  # ===========================================

  test "generate with unknown format raises error" do
    mock_resolver = Minitest::Mock.new
    mock_resolver.expect :resolve_all, {}

    SecretResolver.stub :new, mock_resolver do
      assert_raises(ArgumentError) do
        @generator.generate(format: :invalid)
      end
    end
  end
end
