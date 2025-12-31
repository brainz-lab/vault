# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class AccessTokensControllerTest < ActionDispatch::IntegrationTest
      setup do
        @project = projects(:acme)
        @token, @raw_token = create_token_with_raw_value(
          project: @project,
          permissions: %w[read write admin]
        )
      end

      test "index requires authentication" do
        get api_v1_access_tokens_path
        assert_response :unauthorized
      end

      test "index returns list of tokens" do
        get api_v1_access_tokens_path, headers: auth_headers
        assert_response :success
        assert json_response["tokens"].is_a?(Array)
      end

      test "create creates new token" do
        assert_difference "AccessToken.count", 1 do
          post api_v1_access_tokens_path,
               params: { name: "New Token", permissions: %w[read] },
               headers: auth_headers

          assert_response :created
        end

        assert json_response["token"].present?
      end

      test "create requires admin permission" do
        read_token, raw = create_token_with_raw_value(
          project: @project,
          permissions: %w[read]
        )

        post api_v1_access_tokens_path,
             params: { name: "New Token", permissions: %w[read] },
             headers: { "Authorization" => "Bearer #{raw}" }

        assert_response :forbidden
      end

      test "show returns token details" do
        get api_v1_access_token_path(@token.id), headers: auth_headers
        assert_response :success
        assert_equal @token.name, json_response["name"]
      end

      test "destroy revokes token" do
        delete api_v1_access_token_path(@token.id), headers: auth_headers
        assert_response :no_content

        @token.reload
        assert @token.revoked?
      end

      private

      def auth_headers
        { "Authorization" => "Bearer #{@raw_token}" }
      end
    end
  end
end
