class CleanupVersionsJob < ApplicationJob
  queue_as :low

  # Run daily to clean up old secret versions
  def perform(project_id: nil, keep_versions: 10, older_than_days: 90)
    projects = project_id ? Project.where(id: project_id) : Project.all

    total_deleted = 0

    projects.find_each do |project|
      deleted = cleanup_project_versions(project, keep_versions, older_than_days)
      total_deleted += deleted
    end

    Rails.logger.info "[CleanupVersionsJob] Deleted #{total_deleted} old versions"
  end

  private

  def cleanup_project_versions(project, keep_versions, older_than_days)
    cutoff_date = older_than_days.days.ago
    deleted_count = 0

    project.secrets.find_each do |secret|
      # Group by environment and keep recent versions
      secret.secret_versions
            .group_by(&:secret_environment_id)
            .each do |_env_id, versions|
              # Skip if not enough versions
              next if versions.count <= keep_versions

              # Sort by version descending
              sorted = versions.sort_by { |v| -v.version }

              # Versions to potentially delete (after keep_versions)
              candidates = sorted[keep_versions..]

              # Only delete if older than cutoff
              to_delete = candidates.select { |v| v.created_at < cutoff_date }

              to_delete.each do |version|
                version.destroy
                deleted_count += 1
              end
            end
      end

    deleted_count
  end
end
