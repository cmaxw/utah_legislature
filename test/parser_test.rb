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

  REDLINE_XML = <<~XML
    <?xml version="1.0" encoding="UTF-16"?>
    <leg xml:space="preserve"><bdy><bsec><section>
      <secline lineno="10">Section 1. Section 10-1-1 is amended to read:</secline>
      <subsection lineno="12" level="1"><display>(1)</display> "Office" means the <amend ea="erase" style="2">old office</amend><amend ea="amend" style="1">Office of Policy Research</amend>.</subsection>
    </section></bsec></bdy></leg>
  XML

  def test_redline_defaults_to_html_with_line_numbers_and_amendments
    html = UtahLegislature::Parser.redline(REDLINE_XML)

    assert html.start_with?("<div"), "default format should be HTML"
    assert_includes html, %(<span class="ul-linenum">10</span>)
    assert_includes html, "<del>old office</del>"
    assert_includes html, "<ins>Office of Policy Research</ins>"
  end

  def test_redline_markdown_format
    md = UtahLegislature::Parser.redline(REDLINE_XML, format: :markdown)

    assert_includes md, "~~old office~~"
    assert_includes md, "<ins>Office of Policy Research</ins>"
    assert_match(/^\s*10\s/, md) # line number prefix
  end

  def test_redline_blank_input
    assert_equal "", UtahLegislature::Parser.redline(nil)
    assert_equal "", UtahLegislature::Parser.redline("")
  end
end
