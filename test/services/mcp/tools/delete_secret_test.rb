# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class DeleteSecretTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @secret = secrets(:acme_api_key)
        @tool = DeleteSecret.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert DeleteSecret::DESCRIPTION.present?
      end

      test "INPUT_SCHEMA requires key" do
        assert_includes DeleteSecret::INPUT_SCHEMA[:required], "key"
      end

      test "call returns error when key is missing" do
        result = @tool.call({})

        refute result[:success]
        assert_includes result[:error], "key"
      end

      test "call returns error when secret not found" do
        result = @tool.call(key: "NON_EXISTENT")

        refute result[:success]
        assert_includes result[:error], "not found"
      end

      test "call archives the secret" do
        result = @tool.call(key: @secret.key)

        assert result[:success]
        @secret.reload
        assert @secret.archived?
      end

      test "call creates audit log" do
        # Note: archive! also creates an audit log, so we expect 2 total
        assert_difference "AuditLog.count", 2 do
          @tool.call(key: @secret.key)
        end
      end
    end
  end
end
