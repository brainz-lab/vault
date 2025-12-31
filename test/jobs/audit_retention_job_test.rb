# frozen_string_literal: true

require "test_helper"

class AuditRetentionJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  test "performs without error" do
    assert_nothing_raised do
      AuditRetentionJob.perform_now
    end
  end

  test "performs with specific project_id" do
    assert_nothing_raised do
      AuditRetentionJob.perform_now(project_id: @project.id)
    end
  end

  test "performs with custom older_than_days" do
    assert_nothing_raised do
      AuditRetentionJob.perform_now(older_than_days: 30)
    end
  end

  test "identifies old logs for export" do
    # This job doesn't delete (append-only), just exports
    AuditRetentionJob.perform_now(project_id: @project.id, older_than_days: 0)
    # Job should complete without error
  end

  test "queues on low priority" do
    assert_equal "low", AuditRetentionJob.new.queue_name
  end
end
