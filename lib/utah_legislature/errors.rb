# frozen_string_literal: true

module UtahLegislature
  # Base class for all errors raised by this gem.
  class Error < StandardError; end

  # Raised when the API responds with a non-success status or a body that
  # isn't the JSON/XML we expected (e.g. a rate-limit HTML landing page).
  class ResponseError < Error; end
end
