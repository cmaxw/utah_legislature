# frozen_string_literal: true

require "cgi/escape"
require "nokogiri"

module UtahLegislature
  # Converts Utah bill-version XML into usable text.
  #
  # Utah bills are served as XML with a custom <leg> schema whose enacting body
  # lives in <bdy>. Two quirks are handled here:
  #
  #   1. The XML declares encoding="UTF-16" but is actually served as single-byte
  #      content, which makes Nokogiri refuse to parse it (nil root). We rewrite
  #      the declaration to UTF-8 before parsing.
  #   2. Section text is stored inline without line breaks, so we insert a break
  #      before each "Section N." marker — which is also what Chunker keys off.
  module Parser
    module_function

    # Extract clean, section-delimited plain text from bill XML.
    def body_text(xml)
      xml = xml.to_s
      return "" if xml.strip.empty?

      doc = parse(xml)
      return "" if doc.nil?

      body = doc.at_css("bdy") || doc.root
      return "" if body.nil?

      body.text
          .gsub(/(?=Section\s+\d+\.\s)/, "\n") # one line per section marker
          .split("\n")
          .map(&:strip)
          .reject(&:empty?)
          .join("\n")
    end

    # Render plain text as line-numbered HTML (one <div> per line). Useful for
    # display; safe to render (content is HTML-escaped).
    def to_html(text)
      text = text.to_s
      return "" if text.empty?

      text.split("\n").each_with_index.map do |line, i|
        format_line(i + 1, CGI.escapeHTML(line))
      end.join("\n")
    end

    def parse(xml)
      xml = xml.dup.force_encoding("UTF-8")
      xml = xml.sub(/<\?xml[^>]*\?>/i, %(<?xml version="1.0" encoding="UTF-8"?>))
      Nokogiri::XML(xml)
    rescue StandardError => e
      UtahLegislature.logger.warn("[UtahLegislature] Failed to parse XML: #{e.message}")
      nil
    end

    def format_line(number, content)
      "<div class='flex gap-x-4 font-mono text-sm py-0.5'>" \
        "<span class='text-gray-400 select-none w-12 text-right flex-shrink-0'>#{number}</span>" \
        "<span class='flex-1 whitespace-pre-wrap'>#{content}</span>" \
        "</div>"
    end
  end
end
