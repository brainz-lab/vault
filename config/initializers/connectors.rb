# frozen_string_literal: true

# Eager-load connector error classes so Zeitwerk doesn't look for individual files.
# All error subclasses are defined in app/services/connectors/error.rb.
require_relative "../../app/services/connectors/error"
