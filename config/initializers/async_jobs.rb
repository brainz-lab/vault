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
#
# Note: SolidQueue's internal job processing is excluded from this enforcement
# because SolidQueue workers legitimately use perform_now to execute jobs.

Rails.application.config.after_initialize do
  next if Rails.env.local? # Allow sync jobs in development/test
  next if ENV["ALLOW_SYNC_JOBS"] == "true"

  # Jobs that should be allowed to run synchronously (SolidQueue internal jobs)
  SOLID_QUEUE_INTERNAL_JOBS = %w[
    SolidQueue::RecurringJob
  ].freeze

  ActiveJob::Base.class_eval do
    class << self
      alias_method :original_perform_now, :perform_now

      def perform_now(...)
        # Allow SolidQueue internal jobs to run synchronously
        if SOLID_QUEUE_INTERNAL_JOBS.include?(name)
          return original_perform_now(...)
        end

        # Allow if called from within a SolidQueue worker process
        if caller.any? { |line| line.include?("solid_queue") }
          return original_perform_now(...)
        end

        Rails.logger.warn(
          "[AsyncJobEnforcement] Converting #{name}.perform_now to perform_later in #{Rails.env}. " \
          "Set ALLOW_SYNC_JOBS=true to override."
        )
        perform_later(...)
      end
    end

    alias_method :original_instance_perform_now, :perform_now

    # Instance method perform_now also needs to be handled
    def perform_now
      # Allow SolidQueue internal jobs to run synchronously
      if SOLID_QUEUE_INTERNAL_JOBS.include?(self.class.name)
        return original_instance_perform_now
      end

      # Allow if called from within a SolidQueue worker process
      if caller.any? { |line| line.include?("solid_queue") }
        return original_instance_perform_now
      end

      Rails.logger.warn(
        "[AsyncJobEnforcement] Converting #{self.class.name}#perform_now to perform_later in #{Rails.env}. " \
        "Set ALLOW_SYNC_JOBS=true to override."
      )
      enqueue
    end
  end
end
