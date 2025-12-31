# frozen_string_literal: true

require "test_helper"

class CleanupVersionsJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @secret = secrets(:acme_database_url)
    @environment = secret_environments(:acme_development)
  end

  test "performs without error" do
    assert_nothing_raised do
      CleanupVersionsJob.perform_now
    end
  end

  test "performs with specific project_id" do
    assert_nothing_raised do
      CleanupVersionsJob.perform_now(project_id: @project.id)
    end
  end

  test "performs with custom keep_versions" do
    assert_nothing_raised do
      CleanupVersionsJob.perform_now(keep_versions: 5)
    end
  end

  test "keeps recent versions" do
    # Fixtures already have versions for this secret
    initial_count = @secret.versions.count

    CleanupVersionsJob.perform_now(
      project_id: @project.id,
      keep_versions: 10,
      older_than_days: 0
    )

    # Should keep all since we keep 10 and have fewer
    assert_equal initial_count, @secret.versions.count
  end

  test "queues on low priority" do
    assert_equal "low", CleanupVersionsJob.new.queue_name
  end
end
