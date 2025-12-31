# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class BaseTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @tool = Base.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert_equal "Base tool", Base::DESCRIPTION
      end

      test "INPUT_SCHEMA is defined" do
        assert_equal "object", Base::INPUT_SCHEMA[:type]
      end

      test "call raises NotImplementedError" do
        assert_raises(NotImplementedError) do
          @tool.call({})
        end
      end

      test "success returns success hash" do
        result = @tool.send(:success, { key: "value" })
        assert result[:success]
        assert_equal({ key: "value" }, result[:data])
      end

      test "error returns error hash" do
        result = @tool.send(:error, "Something went wrong")
        refute result[:success]
        assert_equal "Something went wrong", result[:error]
      end

      test "log_access creates audit log" do
        assert_difference "AuditLog.count", 1 do
          @tool.send(:log_access, action: "test_action")
        end
      end
    end
  end
end
