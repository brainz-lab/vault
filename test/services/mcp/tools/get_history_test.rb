# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class GetHistoryTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @secret = secrets(:acme_database_url)
        @tool = GetHistory.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert GetHistory::DESCRIPTION.present?
      end

      test "INPUT_SCHEMA requires key" do
        assert_includes GetHistory::INPUT_SCHEMA[:required], "key"
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

      test "call returns version history" do
        result = @tool.call(key: @secret.key)

        assert result[:success]
        assert_equal @secret.key, result[:data][:key]
        assert result[:data][:versions].is_a?(Array)
      end

      test "call creates audit log" do
        assert_difference "AuditLog.count", 1 do
          @tool.call(key: @secret.key)
        end
      end
    end
  end
end
