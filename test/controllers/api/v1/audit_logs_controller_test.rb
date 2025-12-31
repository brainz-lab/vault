# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class AuditLogsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @project = projects(:acme)
        @token, @raw_token = create_token_with_raw_value(
          project: @project,
          permissions: %w[read write admin]
        )
      end

      test "index requires authentication" do
        get api_v1_audit_logs_path
        assert_response :unauthorized
      end

      test "index returns list of audit logs" do
        get api_v1_audit_logs_path, headers: auth_headers
        assert_response :success
        assert json_response["audit_logs"].is_a?(Array)
      end

      test "index filters by action" do
        get api_v1_audit_logs_path, params: { action: "read" }, headers: auth_headers
        assert_response :success
      end

      test "index filters by environment" do
        get api_v1_audit_logs_path, params: { environment: "development" }, headers: auth_headers
        assert_response :success
      end

      test "index filters by date range" do
        get api_v1_audit_logs_path,
            params: { from: 1.day.ago.iso8601, to: Time.current.iso8601 },
            headers: auth_headers
        assert_response :success
      end

      test "index paginates results" do
        get api_v1_audit_logs_path, params: { limit: 10, offset: 0 }, headers: auth_headers
        assert_response :success
      end

      private

      def auth_headers
        { "Authorization" => "Bearer #{@raw_token}" }
      end
    end
  end
end
