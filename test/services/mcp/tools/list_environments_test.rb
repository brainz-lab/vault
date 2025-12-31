# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class ListEnvironmentsTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @tool = ListEnvironments.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert ListEnvironments::DESCRIPTION.present?
      end

      test "INPUT_SCHEMA is defined" do
        assert ListEnvironments::INPUT_SCHEMA.present?
      end

      test "call returns list of environments" do
        result = @tool.call({})

        assert result[:success]
        assert result[:data][:environments].is_a?(Array)
        assert result[:data][:current].present?
      end

      test "call includes environment details" do
        result = @tool.call({})

        env = result[:data][:environments].first
        assert env[:name].present?
        assert env[:slug].present?
      end
    end
  end
end
