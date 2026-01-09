# Patch for phlex-rails 2.3.1 compatibility with Rails 8.1+
# See: https://github.com/phlex-ruby/phlex-rails/issues/323
#
# Rails 8.1+ ActionController::Live has an `included` block that calls `class_attribute`.
# When Phlex::Rails::Streaming includes this module as a plain module, the block executes
# in the wrong context.
#
# This patch redefines the module with ActiveSupport::Concern extended FIRST,
# which defers the `included` block to the actual controller class.
#
# Remove this patch once phlex-rails fixes this issue.

# Prevent phlex-rails from loading its problematic Streaming module
# by ensuring our patched version loads first with proper Concern support
Rails.application.config.after_initialize do
  # Only patch if the module exists and has the problem
  if defined?(Phlex::Rails::Streaming)
    # Remove the old module and recreate with proper Concern extension
    Phlex::Rails.send(:remove_const, :Streaming) if Phlex::Rails.const_defined?(:Streaming, false)

    module Phlex::Rails::Streaming
      extend ActiveSupport::Concern
      include ActionController::Live
    end
  end
end
