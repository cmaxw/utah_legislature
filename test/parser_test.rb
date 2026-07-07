# frozen_string_literal: true

require "test_helper"

class ParserTest < Minitest::Test
  def setup
    @xml = File.read(File.expand_path("fixtures/sample_bill.xml", __dir__))
  end

  def test_extracts_body_text_despite_bogus_utf16_declaration
    text = UtahLegislature::Parser.body_text(@xml)

    assert_includes text, "research office"
    # <foot>/<info> chrome is excluded — only <bdy> is returned.
    refute_includes text, "Legislative footer text"
    refute_includes text, "Sample Bill Title"
  end

  def test_inserts_line_breaks_before_section_markers
    text = UtahLegislature::Parser.body_text(@xml)
    lines = text.split("\n")

    assert_equal 2, lines.length
    assert(lines.all? { |l| l.start_with?("Section ") })
  end

  def test_to_html_line_numbers_and_escapes
    html = UtahLegislature::Parser.to_html("Section 1. a < b")

    assert_includes html, ">1<"          # line number gutter
    assert_includes html, "a &lt; b"     # escaped content
  end

  def test_blank_input
    assert_equal "", UtahLegislature::Parser.body_text(nil)
    assert_equal "", UtahLegislature::Parser.body_text("")
  end
end
