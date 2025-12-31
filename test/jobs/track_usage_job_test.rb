# frozen_string_literal: true

require "test_helper"

class TrackUsageJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  test "performs without error when platform not configured" do
    # Without BRAINZLAB_PLATFORM_URL, job should skip
    assert_nothing_raised do
      TrackUsageJob.perform_now(
        project_id: @project.id,
        product: "vault",
        metric: "secrets_read",
        count: 1
      )
    end
  end

  test "queues on low priority" do
    assert_equal "low", TrackUsageJob.new.queue_name
  end

  test "handles missing project gracefully" do
    # Job should handle errors gracefully
    assert_nothing_raised do
      TrackUsageJob.perform_now(
        project_id: SecureRandom.uuid,
        product: "vault",
        metric: "secrets_read",
        count: 1
      )
    end
  end
end
