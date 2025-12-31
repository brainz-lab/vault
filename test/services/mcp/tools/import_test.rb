# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class ImportTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @tool = Import.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert Import::DESCRIPTION.present?
      end

      test "INPUT_SCHEMA requires content" do
        assert_includes Import::INPUT_SCHEMA[:required], "content"
      end

      test "call returns error when content is missing" do
        result = @tool.call({})

        refute result[:success]
        assert result[:error].present?
      end

      # Note: Import tests that require encryption are skipped because
      # fixtures don't have valid encryption keys. Integration tests
      # would cover the full import flow.
    end
  end
end
