# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class EnvironmentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @token, @raw_token = create_token_with_raw_value(
          project: @project,
          permissions: %w[read write admin]
        )
      end

      test "index requires authentication" do
        get api_v1_environments_path
        assert_response :unauthorized
      end

      test "index returns list of environments" do
        get api_v1_environments_path, headers: auth_headers
        assert_response :success
        assert json_response["environments"].is_a?(Array)
      end

      test "show returns environment details" do
        get api_v1_environment_path(@environment.slug), headers: auth_headers
        assert_response :success
        assert_equal @environment.name, json_response["name"]
      end

      test "create creates new environment" do
        assert_difference "SecretEnvironment.count", 1 do
          post api_v1_environments_path,
               params: { name: "Staging", slug: "staging" },
               headers: auth_headers

          assert_response :created
        end
      end

      test "update updates environment" do
        patch api_v1_environment_path(@environment.slug),
              params: { name: "Updated Name" },
              headers: auth_headers

        assert_response :success
        @environment.reload
        assert_equal "Updated Name", @environment.name
      end

      test "destroy deletes environment" do
        env = @project.secret_environments.create!(name: "Temp", slug: "temp")

        delete api_v1_environment_path(env.slug), headers: auth_headers
        assert_response :no_content
      end

      private

      def auth_headers
        { "Authorization" => "Bearer #{@raw_token}" }
      end
    end
  end
end
