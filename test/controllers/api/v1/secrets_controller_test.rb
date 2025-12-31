# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class SecretsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @project = projects(:acme)
        @environment = secret_environments(:acme_development)
        @secret = secrets(:acme_database_url)
        @token, @raw_token = create_token_with_raw_value(
          project: @project,
          permissions: %w[read write admin]
        )
      end

      # ===========================================
      # Authentication
      # ===========================================

      test "index requires authentication" do
        get api_v1_secrets_path
        assert_response :unauthorized
        assert_equal "Unauthorized", json_response["error"]
      end

      test "index accepts Bearer token authentication" do
        get api_v1_secrets_path, headers: { "Authorization" => "Bearer #{@raw_token}" }
        assert_response :success
      end

      test "index accepts X-API-Key authentication" do
        get api_v1_secrets_path, headers: { "X-API-Key" => @raw_token }
        assert_response :success
      end

      test "index accepts project API key authentication" do
        get api_v1_secrets_path, headers: { "X-API-Key" => @project.api_key }
        assert_response :success
      end

      # ===========================================
      # GET /api/v1/secrets (index)
      # ===========================================

      test "index returns list of secrets" do
        get api_v1_secrets_path, headers: auth_headers
        assert_response :success

        assert json_response["secrets"].is_a?(Array)
        assert json_response["total"].is_a?(Integer)
      end

      test "index filters by folder" do
        folder = @project.secret_folders.create!(name: "test-folder", path: "test")
        @secret.update!(secret_folder: folder)

        get api_v1_secrets_path, params: { folder: "test" }, headers: auth_headers
        assert_response :success
      end

      test "index creates audit log" do
        assert_difference "AuditLog.count", 1 do
          get api_v1_secrets_path, headers: auth_headers
        end
      end

      # ===========================================
      # GET /api/v1/secrets/:key (show)
      # ===========================================

      test "show returns secret value" do
        # Create a version with encrypted value
        create_secret_version(secret: @secret, environment: @environment, value: "test_value")

        get api_v1_secret_path(@secret.key),
            params: { environment: @environment.slug },
            headers: auth_headers

        assert_response :success
        assert_equal @secret.key, json_response["key"]
        assert json_response.key?("value")
        assert_equal @environment.slug, json_response["environment"]
      end

      test "show returns 404 for non-existent secret" do
        get api_v1_secret_path("NON_EXISTENT_KEY"),
            params: { environment: @environment.slug },
            headers: auth_headers

        assert_response :not_found
      end

      test "show returns 404 for non-existent environment" do
        get api_v1_secret_path(@secret.key),
            params: { environment: "non_existent" },
            headers: auth_headers

        assert_response :not_found
      end

      # ===========================================
      # POST /api/v1/secrets (create)
      # ===========================================

      test "create creates new secret" do
        assert_difference "Secret.count", 1 do
          post api_v1_secrets_path,
               params: { key: "NEW_SECRET", value: "secret_value", environment: @environment.slug },
               headers: auth_headers

          assert_response :created
        end

        assert_equal "NEW_SECRET", json_response["key"]
      end

      test "create requires write permission" do
        read_only_token, raw = create_token_with_raw_value(
          project: @project,
          permissions: %w[read]
        )

        post api_v1_secrets_path,
             params: { key: "NEW_SECRET", value: "secret_value", environment: @environment.slug },
             headers: { "Authorization" => "Bearer #{raw}" }

        assert_response :forbidden
      end

      test "create updates existing secret" do
        post api_v1_secrets_path,
             params: { key: @secret.key, value: "updated_value", environment: @environment.slug },
             headers: auth_headers

        assert_response :created
      end

      # ===========================================
      # PUT /api/v1/secrets/:key (update)
      # ===========================================

      test "update updates secret" do
        put api_v1_secret_path(@secret.key),
            params: { value: "new_value", environment: @environment.slug },
            headers: auth_headers

        assert_response :success
      end

      test "update requires write permission" do
        read_only_token, raw = create_token_with_raw_value(
          project: @project,
          permissions: %w[read]
        )

        put api_v1_secret_path(@secret.key),
            params: { value: "new_value", environment: @environment.slug },
            headers: { "Authorization" => "Bearer #{raw}" }

        assert_response :forbidden
      end

      # ===========================================
      # DELETE /api/v1/secrets/:key (destroy)
      # ===========================================

      test "destroy archives secret" do
        delete api_v1_secret_path(@secret.key), headers: auth_headers
        assert_response :no_content

        @secret.reload
        assert @secret.archived?
      end

      test "destroy requires admin permission" do
        write_token, raw = create_token_with_raw_value(
          project: @project,
          permissions: %w[read write]
        )

        delete api_v1_secret_path(@secret.key),
               headers: { "Authorization" => "Bearer #{raw}" }

        assert_response :forbidden
      end

      # ===========================================
      # GET /api/v1/secrets/:key/versions
      # ===========================================

      test "versions returns version history" do
        create_secret_version(secret: @secret, environment: @environment, value: "v1", version: 1)
        create_secret_version(secret: @secret, environment: @environment, value: "v2", version: 2)

        get versions_api_v1_secret_path(@secret.key), headers: auth_headers
        assert_response :success

        assert_equal @secret.key, json_response["key"]
        assert json_response["versions"].is_a?(Array)
      end

      # ===========================================
      # POST /api/v1/secrets/:key/rollback
      # ===========================================

      test "rollback creates new version from old version" do
        create_secret_version(secret: @secret, environment: @environment, value: "v1", version: 1)
        create_secret_version(secret: @secret, environment: @environment, value: "v2", version: 2)

        # Mock the decrypt method since we don't have real encryption in tests
        SecretVersion.any_instance.stubs(:decrypt).returns("v1")

        post rollback_api_v1_secret_path(@secret.key),
             params: { version: 1, environment: @environment.slug },
             headers: auth_headers

        assert_response :success
        assert_equal 1, json_response["rolled_back_to"]
      end

      private

      def auth_headers
        { "Authorization" => "Bearer #{@raw_token}" }
      end
    end
  end
end
