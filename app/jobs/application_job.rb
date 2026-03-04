class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  rescue_from(StandardError) do |exception|
    BrainzLab::Reflex.capture(exception, context: { job: self.class.name, arguments: arguments })
    BrainzLab::Recall.error("Job failed: #{self.class.name}", error: exception.message)
    BrainzLab::Signal.trigger("job.failure", severity: :high, details: { job: self.class.name, error: exception.message })
    raise exception
  end

  # Add logging
  around_perform do |job, block|
    Rails.logger.info "[#{job.class.name}] Starting job with args: #{job.arguments.inspect}"
    start_time = Time.current
    block.call
    duration = Time.current - start_time
    Rails.logger.info "[#{job.class.name}] Completed in #{duration.round(2)}s"
  rescue => e
    Rails.logger.error "[#{job.class.name}] Failed with error: #{e.message}"
    raise
  end
end
