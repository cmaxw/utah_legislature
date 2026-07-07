# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "utah_legislature"
require "minitest/autorun"

module UtahLegislature
  module TestHelpers
    # A minimal stand-in for a Faraday response.
    Response = Data.define(:status, :body, :headers) do
      def success? = status.between?(200, 299)
    end

    # A fake connection that returns canned responses keyed by URL substring.
    class FakeConnection
      def initialize(routes) = @routes = routes

      def get(url)
        _, response = @routes.find { |pattern, _| url.include?(pattern) }
        raise "no stubbed route for #{url}" unless response

        response.respond_to?(:call) ? response.call(url) : response
      end
    end

    def xml_response(body)
      Response.new(status: 200, body: body, headers: { "content-type" => "text/xml" })
    end

    def json_response(body)
      Response.new(status: 200, body: body, headers: { "content-type" => "application/json" })
    end
  end
end
