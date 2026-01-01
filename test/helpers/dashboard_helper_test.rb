# frozen_string_literal: true

require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  include DashboardHelper

  # ===========================================
  # Icon helper
  # ===========================================

  test "icon returns html safe svg for known icons" do
    %i[overview secrets environments access_tokens audit_logs provider_keys settings mcp].each do |icon_name|
      result = icon(icon_name)
      assert result.present?, "Icon #{icon_name} should return content"
      assert result.html_safe?, "Icon #{icon_name} should be html_safe"
      assert_includes result, "<svg", "Icon #{icon_name} should contain svg"
    end
  end

  test "icon returns nil for unknown icon" do
    assert_nil icon(:unknown_icon)
  end

  # ===========================================
  # Action badge helper
  # ===========================================

  test "action_badge_class returns badge-green for create actions" do
    assert_equal "badge-green", action_badge_class("create_secret")
    assert_equal "badge-green", action_badge_class("create_token")
  end

  test "action_badge_class returns badge-blue for update actions" do
    assert_equal "badge-blue", action_badge_class("update_secret")
    assert_equal "badge-blue", action_badge_class("set_value")
  end

  test "action_badge_class returns badge-red for delete actions" do
    assert_equal "badge-red", action_badge_class("delete_secret")
    assert_equal "badge-red", action_badge_class("archive_secret")
    assert_equal "badge-red", action_badge_class("revoke_token")
  end

  test "action_badge_class returns badge-gray for read actions" do
    assert_equal "badge-gray", action_badge_class("read_secret")
    assert_equal "badge-gray", action_badge_class("get_value")
    assert_equal "badge-gray", action_badge_class("list_secrets")
    assert_equal "badge-gray", action_badge_class("export_secrets")
  end

  test "action_badge_class returns badge-yellow for rollback" do
    assert_equal "badge-yellow", action_badge_class("rollback_secret")
  end

  test "action_badge_class returns badge-orange for import" do
    assert_equal "badge-orange", action_badge_class("import_secrets")
  end

  test "action_badge_class returns badge-gray for unknown actions" do
    assert_equal "badge-gray", action_badge_class("unknown_action")
  end

  # ===========================================
  # Provider badge helper
  # ===========================================

  test "provider_badge_class returns correct class for known providers" do
    provider_classes = {
      "openai" => "bg-green-100 text-green-700",
      "anthropic" => "bg-orange-100 text-orange-700",
      "google" => "bg-blue-100 text-blue-700",
      "azure" => "bg-sky-100 text-sky-700",
      "cohere" => "bg-purple-100 text-purple-700",
      "mistral" => "bg-indigo-100 text-indigo-700",
      "groq" => "bg-yellow-100 text-yellow-700",
      "replicate" => "bg-pink-100 text-pink-700",
      "huggingface" => "bg-amber-100 text-amber-700"
    }

    provider_classes.each do |provider, expected_class|
      assert_equal expected_class, provider_badge_class(provider), "Provider #{provider} should have correct class"
      assert_equal expected_class, provider_badge_class(provider.upcase), "Provider #{provider.upcase} should have correct class"
    end
  end

  test "provider_badge_class returns default class for unknown providers" do
    assert_equal "bg-stone-100 text-stone-700", provider_badge_class("unknown_provider")
  end
end
