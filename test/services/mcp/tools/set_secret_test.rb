# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class SetSecretTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @tool = SetSecret.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert SetSecret::DESCRIPTION.present?
      end

      test "INPUT_SCHEMA requires key and value" do
        assert_includes SetSecret::INPUT_SCHEMA[:required], "key"
        assert_includes SetSecret::INPUT_SCHEMA[:required], "value"
      end

      test "call returns error when key is missing" do
        result = @tool.call(value: "test")

        refute result[:success]
        assert result[:error].present?
      end

      test "call returns error when value is missing" do
        result = @tool.call(key: "TEST_KEY")

        refute result[:success]
        assert result[:error].present?
      end

      # Note: Tests that require encryption are skipped because fixtures
      # don't have valid encryption keys. Integration tests would cover
      # the full set_secret flow with real encryption.
    end
  end
end
