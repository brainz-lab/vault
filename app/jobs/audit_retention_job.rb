class AuditRetentionJob < ApplicationJob
  queue_as :low

  # Run weekly to archive/export old audit logs
  # Note: We don't delete audit logs due to append-only rules
  # Instead, we can export them to external storage
  def perform(project_id: nil, older_than_days: 365)
    projects = project_id ? Project.where(id: project_id) : Project.all
    cutoff_date = older_than_days.days.ago

    projects.find_each do |project|
      old_logs = project.audit_logs.where("created_at < ?", cutoff_date)
      count = old_logs.count

      next if count.zero?

      # Export to external storage if configured
      if export_enabled?
        export_logs(project, old_logs)
        Rails.logger.info "[AuditRetentionJob] Exported #{count} logs for project #{project.id}"
      else
        Rails.logger.info "[AuditRetentionJob] #{count} old logs found for project #{project.id} (export not configured)"
      end
    end
  end

  private

  def export_enabled?
    ENV["AUDIT_EXPORT_BUCKET"].present?
  end

  def export_logs(project, logs)
    # Future: Export to S3/GCS
    # For now, just log the count
    filename = "audit_logs_#{project.id}_#{Date.current.iso8601}.jsonl"

    content = logs.map do |log|
      {
        id: log.id,
        project_id: log.project_id,
        secret_id: log.secret_id,
        action: log.action,
        actor_type: log.actor_type,
        actor_id: log.actor_id,
        actor_name: log.actor_name,
        ip_address: log.ip_address,
        user_agent: log.user_agent,
        details: log.details,
        created_at: log.created_at.iso8601
      }.to_json
    end.join("\n")

    Rails.logger.info "[AuditRetentionJob] Would export #{content.bytesize} bytes to #{filename}"
  end
end
