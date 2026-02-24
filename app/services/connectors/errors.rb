module Connectors
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
  class TimeoutError < Error; end
  class NotConnectedError < Error; end
  class ActionNotFoundError < Error; end
  class SidecarUnavailableError < Error; end
end
