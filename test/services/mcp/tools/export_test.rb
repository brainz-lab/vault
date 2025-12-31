# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class ExportTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @tool = Export.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert Export::DESCRIPTION.present?
      end

      test "INPUT_SCHEMA is defined" do
        assert Export::INPUT_SCHEMA.present?
      end

      # Note: Export tests that require decryption are skipped because
      # fixtures have fake encrypted values. Integration tests with
      # real encryption would test the full export flow.
    end
  end
end
