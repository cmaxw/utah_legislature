# frozen_string_literal: true

require "cgi/escape"
require "nokogiri"

module UtahLegislature
  # Converts Utah bill-version XML into usable text.
  #
  # Utah bills are served as XML with a custom <leg> schema whose enacting body
  # lives in <bdy>. The XML declares encoding="UTF-16" but is actually served as
  # single-byte content, which makes Nokogiri refuse to parse it (nil root); we
  # rewrite the declaration to UTF-8 before parsing.
  #
  # Amendments are marked inline with <amend> elements: `ea="erase"` (or
  # `style="2"`) is struck-through text being removed, `ea="amend"` (or
  # `style="1"`) is underlined text being added. Structural elements carry a
  # `lineno` attribute; subsections nest.
  module Parser
    module_function

    # Elements that render as their own numbered line.
    LINE_ELEMENTS = %w[secline catline sectionText intro].freeze
    # Elements that nest and get their own line plus indented children.
    CONTAINER_ELEMENTS = %w[subsection subpara paragraph lineitem].freeze

    # Extract clean, section-delimited plain text from bill XML. Used for search
    # and chunking (amendments are flattened to their resulting text).
    def body_text(xml)
      xml = xml.to_s
      return "" if xml.strip.empty?

      doc = parse(xml)
      body = doc&.at_css("bdy") || doc&.root
      return "" if body.nil?

      body.text
          .gsub(/(?=Section\s+\d+\.\s)/, "\n") # one line per section marker
          .split("\n")
          .map(&:strip)
          .reject(&:empty?)
          .join("\n")
    end

    # Render the bill's redline (line numbers, struck-through deletions,
    # underlined additions, indented subsections). Returns HTML by default, or
    # Markdown with `format: :markdown`.
    def redline(xml, format: :html)
      xml = xml.to_s
      return "" if xml.strip.empty?

      doc = parse(xml)
      body = doc&.at_css("bdy") || doc&.root
      return "" if body.nil?

      rows = []
      collect_rows(body, rows, 0, format)

      format == :markdown ? rows.map { |row| markdown_row(row) }.join("\n") : html_rows(rows)
    end

    # --- internals ---------------------------------------------------------

    def collect_rows(node, rows, indent, format)
      node.element_children.each do |el|
        if LINE_ELEMENTS.include?(el.name)
          rows << { line: el["lineno"], indent: indent, content: inline(el, format) }
        elsif CONTAINER_ELEMENTS.include?(el.name)
          own = inline(el, format, skip: CONTAINER_ELEMENTS).strip
          rows << { line: el["lineno"], indent: indent, content: own } unless own.empty?
          collect_rows(el, rows, indent + 1, format)
        else
          collect_rows(el, rows, indent, format)
        end
      end
    end

    # Render a node's inline content for the given format, optionally skipping
    # named child elements (used to keep nested subsections out of a parent row).
    def inline(node, format, skip: [])
      node.children.map do |child|
        next "" if child.element? && skip.include?(child.name)

        case child.name
        when "text" then escape(child.text, format)
        when "bold" then wrap(inline(child, format, skip: skip), :bold, format)
        when "amend"
          inner = inline(child, format, skip: skip)
          deletion?(child) ? wrap(inner, :del, format) : wrap(inner, :ins, format)
        when "tab" then format == :markdown ? "    " : "&emsp;"
        when "display" then "#{inline(child, format, skip: skip)} "
        else inline(child, format, skip: skip)
        end
      end.join
    end

    def deletion?(node)
      node["ea"] == "erase" || node["style"] == "2"
    end

    def wrap(inner, kind, format)
      if format == :markdown
        case kind
        when :bold then "**#{inner}**"
        when :del then "~~#{inner}~~"
        when :ins then "<ins>#{inner}</ins>" # GFM has no underline; keep inline HTML
        end
      else
        tag = { bold: "strong", del: "del", ins: "ins" }.fetch(kind)
        "<#{tag}>#{inner}</#{tag}>"
      end
    end

    def escape(text, format)
      if format == :markdown
        text.to_s.gsub(/([\\`*_~\[\]])/) { "\\#{Regexp.last_match(1)}" }
      else
        CGI.escapeHTML(text.to_s)
      end
    end

    def html_rows(rows)
      rows.map do |row|
        num = row[:line]
        pad = row[:indent]
        text = row[:content]
        %(<div class="ul-line"><span class="ul-linenum">#{num}</span><span class="ul-linetext" style="padding-left: #{pad}rem">#{text}</span></div>)
      end.join("\n")
    end

    def markdown_row(row)
      "#{row[:line].to_s.rjust(5)}  #{"  " * row[:indent]}#{row[:content]}".rstrip
    end

    def parse(xml)
      xml = xml.dup.force_encoding("UTF-8")
      xml = xml.sub(/<\?xml[^>]*\?>/i, %(<?xml version="1.0" encoding="UTF-8"?>))
      Nokogiri::XML(xml)
    rescue StandardError => e
      UtahLegislature.logger.warn("[UtahLegislature] Failed to parse XML: #{e.message}")
      nil
    end

    # Render already-plain text as line-numbered HTML (one <div> per line).
    # Retained for callers that store the flattened body_text.
    def to_html(text)
      text = text.to_s
      return "" if text.empty?

      text.split("\n").each_with_index.map do |line, i|
        format_line(i + 1, CGI.escapeHTML(line))
      end.join("\n")
    end

    def format_line(number, content)
      "<div class='flex gap-x-4 font-mono text-sm py-0.5'>" \
        "<span class='text-gray-400 select-none w-12 text-right flex-shrink-0'>#{number}</span>" \
        "<span class='flex-1 whitespace-pre-wrap'>#{content}</span>" \
        "</div>"
    end
  end
end
