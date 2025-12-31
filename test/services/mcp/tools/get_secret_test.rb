# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class GetSecretTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @secret = secrets(:acme_database_url)
        @tool = GetSecret.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert_includes GetSecret::DESCRIPTION, "Retrieve the value"
      end

      test "INPUT_SCHEMA requires key" do
        assert_includes GetSecret::INPUT_SCHEMA[:required], "key"
      end

      test "call returns error when key is missing" do
        result = @tool.call({})

        refute result[:success]
        assert_includes result[:error], "key is required"
      end

      test "call returns error when secret not found" do
        result = @tool.call(key: "NON_EXISTENT_SECRET")

        refute result[:success]
        assert_includes result[:error], "not found"
      end

      # Note: Testing actual decryption requires valid encryption keys
      # These tests verify the tool structure and error handling
    end
  end
end
