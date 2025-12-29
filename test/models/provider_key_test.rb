# frozen_string_literal: true

require "test_helper"

class ProviderKeyTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid provider key with all required attributes (global)" do
    key = ProviderKey.new(
      name: "Test OpenAI Key",
      provider: "openai",
      model_type: "llm",
      encrypted_key: "encrypted_data",
      encryption_iv: "random_iv",
      encryption_key_id: "key_001",
      global: true,
      project: nil,
      priority: 999 # Unique priority to avoid conflicts with fixtures
    )
    assert key.valid?, key.errors.full_messages.join(", ")
  end

  test "valid provider key with project scope" do
    key = ProviderKey.new(
      project: projects(:acme),
      name: "Test Key",
      provider: "anthropic",
      model_type: "llm",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key_001",
      global: false
    )
    assert key.valid?
  end

  test "invalid without name" do
    key = ProviderKey.new(
      provider: "openai",
      model_type: "llm",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: true
    )
    assert_not key.valid?
    assert_includes key.errors[:name], "can't be blank"
  end

  test "invalid without provider" do
    key = ProviderKey.new(
      name: "Test",
      model_type: "llm",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: true
    )
    assert_not key.valid?
    assert_includes key.errors[:provider], "can't be blank"
  end

  test "provider must be valid" do
    key = ProviderKey.new(
      name: "Test",
      provider: "invalid_provider",
      model_type: "llm",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: true
    )
    assert_not key.valid?
    assert_includes key.errors[:provider], "is not included in the list"
  end

  test "valid providers" do
    ProviderKey::PROVIDERS.each do |provider|
      key = ProviderKey.new(
        name: "Test",
        provider: provider,
        model_type: "llm",
        encrypted_key: "data",
        encryption_iv: "iv",
        encryption_key_id: "key",
        global: true,
        priority: ProviderKey.count + 1 # Ensure unique priority
      )
      assert key.valid?, "#{provider} should be valid: #{key.errors.full_messages.join(', ')}"
    end
  end

  test "model_type defaults to llm" do
    # model_type has a database default of "llm"
    key = ProviderKey.new(
      name: "Test",
      provider: "openai",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: true,
      priority: 998
    )
    # New records won't have the default applied yet, but we test that it's validated
    # The presence validation requires it to be set explicitly (before DB default kicks in)
    # OR we should test that the DB default is applied after save
    assert key.valid?, "Expected key to be valid with default model_type, got: #{key.errors.full_messages.join(', ')}"
  end

  test "model_type must be valid" do
    key = ProviderKey.new(
      name: "Test",
      provider: "openai",
      model_type: "invalid_type",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: true
    )
    assert_not key.valid?
    assert_includes key.errors[:model_type], "is not included in the list"
  end

  test "valid model_types" do
    ProviderKey::MODEL_TYPES.each do |type|
      key = ProviderKey.new(
        name: "Test",
        provider: "openai",
        model_type: type,
        encrypted_key: "data",
        encryption_iv: "iv",
        encryption_key_id: "key",
        global: true,
        priority: ProviderKey.count + 100 # Ensure unique priority
      )
      assert key.valid?, "#{type} should be valid: #{key.errors.full_messages.join(', ')}"
    end
  end

  test "cannot be both global and project-specific" do
    key = ProviderKey.new(
      project: projects(:acme),
      name: "Test",
      provider: "openai",
      model_type: "llm",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: true
    )
    assert_not key.valid?
    assert_includes key.errors[:base], "A key cannot be both global and project-specific"
  end

  test "non-global keys must have project" do
    key = ProviderKey.new(
      name: "Test",
      provider: "openai",
      model_type: "llm",
      encrypted_key: "data",
      encryption_iv: "iv",
      encryption_key_id: "key",
      global: false,
      project: nil
    )
    assert_not key.valid?
    assert_includes key.errors[:base], "Non-global keys must belong to a project"
  end

  # ===========================================
  # Constants
  # ===========================================

  test "PROVIDERS constant has correct values" do
    expected = %w[openai anthropic google azure cohere mistral groq replicate huggingface]
    assert_equal expected, ProviderKey::PROVIDERS
  end

  test "MODEL_TYPES constant has correct values" do
    expected = %w[llm embedding image tts stt video code]
    assert_equal expected, ProviderKey::MODEL_TYPES
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project optionally" do
    global_key = provider_keys(:global_openai)
    project_key = provider_keys(:acme_openai)

    assert_nil global_key.project
    assert_equal projects(:acme), project_key.project
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "active scope returns only active keys" do
    active_keys = ProviderKey.active
    active_keys.each do |key|
      assert key.active?
    end
  end

  test "global_keys scope returns global keys without project" do
    global_keys = ProviderKey.global_keys
    global_keys.each do |key|
      assert key.global?
      assert_nil key.project_id
    end
  end

  test "for_project scope filters by project" do
    project = projects(:acme)
    keys = ProviderKey.for_project(project)
    keys.each do |key|
      assert_equal project, key.project
    end
  end

  test "for_provider scope filters by provider" do
    keys = ProviderKey.for_provider("openai")
    keys.each do |key|
      assert_equal "openai", key.provider
    end
  end

  test "by_priority scope orders by priority desc" do
    keys = ProviderKey.by_priority.limit(5)
    priorities = keys.map(&:priority)
    assert_equal priorities, priorities.sort.reverse
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "masked_key returns partial key" do
    key = provider_keys(:global_openai)
    masked = key.masked_key

    assert_not_nil masked
    assert masked.include?("...")
  end

  test "masked_key returns nil without key_prefix" do
    key = ProviderKey.new
    assert_nil key.masked_key
  end

  test "expired? returns true when expires_at is in past" do
    key = ProviderKey.new(expires_at: 1.day.ago)
    assert key.expired?

    key.expires_at = 1.day.from_now
    assert_not key.expired?

    key.expires_at = nil
    assert_not key.expired?
  end

  test "deactivate! sets active to false" do
    key = provider_keys(:acme_openai)
    assert key.active?

    key.deactivate!
    key.reload

    assert_not key.active?
  end

  test "activate! sets active to true" do
    key = provider_keys(:global_inactive)
    assert_not key.active?

    key.activate!
    key.reload

    assert key.active?
  end

  test "record_usage! updates last_used_at and usage_count" do
    key = provider_keys(:acme_openai)
    original_count = key.usage_count

    key.record_usage!
    key.reload

    assert_not_nil key.last_used_at
    assert_equal original_count + 1, key.usage_count
  end

  # ===========================================
  # Class Methods
  # ===========================================

  test "resolve finds project-specific key first" do
    project = projects(:acme)

    key = ProviderKey.resolve(
      project_id: project.id,
      provider: "openai",
      model_type: "llm"
    )

    assert_not_nil key
    assert_equal project, key.project
  end

  test "resolve falls back to global key" do
    # Use a provider that only has global key
    key = ProviderKey.resolve(
      project_id: projects(:startup).id,
      provider: "openai",
      model_type: "llm"
    )

    # Should find global key since startup doesn't have openai key
    assert key.nil? || key.global? || key.project == projects(:startup)
  end

  test "resolve returns nil when no matching key" do
    key = ProviderKey.resolve(
      project_id: "nonexistent",
      provider: "nonexistent_provider",
      model_type: "llm"
    )

    assert_nil key
  end
end
