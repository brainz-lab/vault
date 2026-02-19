# SolidQueue < 1.4 calls ActiveRecord::Base.logger.silence which was
# removed from plain Logger in Rails 8.1. Add a no-op fallback so the
# worker doesn't crash on startup.
Rails.application.config.after_initialize do
  logger = ActiveRecord::Base.logger
  if logger && !logger.respond_to?(:silence)
    logger.define_singleton_method(:silence) { |&block| block.call }
  end
end
