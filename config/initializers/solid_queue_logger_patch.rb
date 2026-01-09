# frozen_string_literal: true

# Patch for Solid Queue 1.2.4 compatibility with Rails 8.1.2
#
# Rails 8.1+ removed the `silence` method from Logger, but Solid Queue 1.2.4
# still expects it to be available on ActiveRecord::Base.logger.
#
# This patch adds the silence method back to Logger if it doesn't exist.
# Can be removed once Solid Queue is updated to support Rails 8.1+
#
# See: https://github.com/rails/solid_queue/issues/XXX

unless Logger.method_defined?(:silence)
  class Logger
    def silence(temporary_level = Logger::ERROR)
      old_level = level
      self.level = temporary_level
      yield
    ensure
      self.level = old_level
    end
  end
end
