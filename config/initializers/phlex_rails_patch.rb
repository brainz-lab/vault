# Patch for phlex-rails 2.3.1 compatibility with Rails 8.1+
# See: https://github.com/phlex-ruby/phlex-rails/issues/323
#
# Rails 8.1+ ActionController::Live has an `included` block that calls `class_attribute`.
# When Phlex::Rails::Streaming includes this module as a plain module, the block executes
# in the wrong context. Extending ActiveSupport::Concern defers the block to the actual
# controller class where `class_attribute` exists.
#
# Remove this patch once phlex-rails fixes this issue.

module Phlex
  module Rails
    module Streaming
      extend ActiveSupport::Concern
      include ActionController::Live
    end
  end
end
