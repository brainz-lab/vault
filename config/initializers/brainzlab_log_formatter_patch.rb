# frozen_string_literal: true

# Monkey-patch for brainzlab gem v0.1.12 LogFormatter bug.
# The gem's `hash_like?` method returns true for Arrays (they respond to :to_h and :each),
# causing `Array#to_h` to be called on flat string arrays like ["ID", "NAME", ...],
# which raises: TypeError: wrong element type String at 0 (expected array)
#
# Fix: exclude Arrays from `hash_like?` check.
# Remove this patch when brainzlab gem is updated to >= 0.1.13.

if defined?(BrainzLab::Rails::LogFormatter)
  BrainzLab::Rails::LogFormatter.class_eval do
    private

    def hash_like?(obj)
      !obj.is_a?(Array) && (obj.is_a?(Hash) || (obj.respond_to?(:to_h) && obj.respond_to?(:each)))
    end
  end
end
