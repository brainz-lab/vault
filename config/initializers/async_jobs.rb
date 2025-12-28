# frozen_string_literal: true

# Async Job Enforcement
# Prevents synchronous job execution (perform_now) in production environments.
# This ensures all jobs are processed by dedicated worker processes.
#
# Why this matters:
# - Separates web request processing from background job processing
# - Prevents request timeouts from long-running jobs
# - Allows proper worker scaling and monitoring
# - Jobs get retried properly on failure
#
# To allow inline execution for specific cases, set:
#   ENV["ALLOW_SYNC_JOBS"] = "true"

Rails.application.config.after_initialize do
  next if Rails.env.local? # Allow sync jobs in development/test
  next if ENV["ALLOW_SYNC_JOBS"] == "true"

  ActiveJob::Base.class_eval do
    class << self
      alias_method :original_perform_now, :perform_now

      def perform_now(...)
        Rails.logger.warn(
          "[AsyncJobEnforcement] Converting #{name}.perform_now to perform_later in #{Rails.env}. " \
          "Set ALLOW_SYNC_JOBS=true to override."
        )
        perform_later(...)
      end
    end

    alias_method :original_perform, :perform

    # Instance method perform_now also needs to be handled
    def perform_now
      Rails.logger.warn(
        "[AsyncJobEnforcement] Converting #{self.class.name}#perform_now to perform_later in #{Rails.env}. " \
        "Set ALLOW_SYNC_JOBS=true to override."
      )
      enqueue
    end
  end
end
