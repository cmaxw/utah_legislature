# frozen_string_literal: true

require "logger"

require_relative "utah_legislature/version"
require_relative "utah_legislature/errors"
require_relative "utah_legislature/resources"
require_relative "utah_legislature/parser"
require_relative "utah_legislature/client"

# A pure-Ruby client for the Utah State Legislature's public API
# (glen.le.utah.gov), including bill-text (XML) fetching and parsing.
#
# It has no Rails/ActiveRecord dependency — the client returns plain value
# objects (see UtahLegislature::Resources) that a host app maps onto its own
# models however it likes.
#
#   client = UtahLegislature::Client.new(api_key: ENV["UTAH_LEGISLATURE_API_KEY"],
#                                        session: "2026GS")
#   client.legislators            # => [UtahLegislature::Legislator, ...]
#   client.bill_list              # => [UtahLegislature::BillSummary, ...]
#   bill = client.bill("HB0001")  # => UtahLegislature::Bill (with text + actions)
#   bill.versions.first.text      # => clean, section-delimited body text
module UtahLegislature
  class << self
    # Where library diagnostics go. Defaults to a silent logger so the gem is
    # quiet unless the host opts in (e.g. `UtahLegislature.logger = Rails.logger`).
    attr_writer :logger

    # Seconds to wait before each bill-text request. le.utah.gov throttles
    # bursts (~30 requests) by serving HTML error pages instead of XML; ~0.3s
    # keeps a bulk sync under the limit.
    attr_accessor :throttle_seconds

    # Faraday connection timeouts (seconds). Without these a single
    # server-held connection can hang an entire sync.
    attr_accessor :open_timeout, :timeout

    def logger
      @logger ||= Logger.new(IO::NULL)
    end

    def configure
      yield self
    end
  end

  self.throttle_seconds = 0.3
  self.open_timeout = 10
  self.timeout = 30
end
