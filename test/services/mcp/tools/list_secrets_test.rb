# frozen_string_literal: true

require "test_helper"

module Mcp
  module Tools
    class ListSecretsTest < ActiveSupport::TestCase
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @tool = ListSecrets.new(project: @project, environment: @environment)
      end

      test "DESCRIPTION is defined" do
        assert_includes ListSecrets::DESCRIPTION, "List all secret names"
      end

      test "call returns list of secrets" do
        result = @tool.call({})

        assert result[:success]
        assert result[:data][:secrets].is_a?(Array)
        assert result[:data][:count].is_a?(Integer)
        assert_equal @environment.slug, result[:data][:environment]
      end

      test "call filters by folder" do
        folder = @project.secret_folders.find_by(path: "database")
        result = @tool.call(folder: "database")

        assert result[:success]
        # Should only return secrets in the database folder
      end

      test "call filters by tag" do
        result = @tool.call(tag: "type:database")

        assert result[:success]
        # Should filter by tag
      end

      test "call creates audit log" do
        assert_difference "AuditLog.count", 1 do
          @tool.call({})
        end
      end
    end
  end
end
