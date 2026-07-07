# UtahLegislature

A dependency-light Ruby client for the [Utah State Legislature](https://le.utah.gov)
public API. It fetches legislators, committees, bills, actions, and bill-version
text, and parses the state's `<leg>` bill XML into clean, section-delimited text.

No Rails dependency — the client returns plain value objects you map onto your
own models however you like.

## Installation

```ruby
# Gemfile
gem "utah_legislature", github: "cmaxw/utah_legislature"
```

Then `bundle install`. (Requires Ruby >= 3.2.)

## Usage

```ruby
require "utah_legislature"

client = UtahLegislature::Client.new(
  api_key: ENV["UTAH_LEGISLATURE_API_KEY"],
  session: "2026GS" # NOTE: session id, not a bare year — "2026GS", "2026S1", ...
)

client.legislators   # => [UtahLegislature::Legislator, ...]
client.committees    # => [UtahLegislature::Committee, ...]
client.bill_list     # => [UtahLegislature::BillSummary(number:, updated_at:), ...]

bill = client.bill("HB0001")
bill.title                       # => "Public Education Base Budget Amendments"
bill.actions.first.description
bill.versions.first.text         # clean, section-delimited body text
```

The returned `text` is clean, section-delimited plain text (each `Section N.`
starts a new line) — ready to index for search or split into passages in your
application layer.

### Rendering bill text as HTML

```ruby
UtahLegislature::Parser.to_html(text) # line-numbered, HTML-escaped <div>s
```

## Configuration

```ruby
UtahLegislature.configure do |c|
  c.logger = Rails.logger      # default: silent
  c.throttle_seconds = 0.3     # delay before each bill-text request (rate-limit safety)
  c.open_timeout = 10
  c.timeout = 30
end
```

## Notes / gotchas this gem handles for you

- **Session ids are `2026GS`, not `2026`** — a bare year 404s.
- **Bill XML lies about its encoding** (`UTF-16` declared, single-byte served);
  the parser rewrites the declaration so Nokogiri can read it.
- **Bill bodies live in `<bdy>`** and store sections inline; the parser extracts
  just the body and breaks on `Section N.` markers.
- **le.utah.gov rate-limits bulk text fetches** by serving HTTP-200 HTML landing
  pages; the client validates that responses are actually XML, throttles, and
  retries with backoff.
- **The API mixes date formats** (`m/d/Y` and ISO timestamps); both are parsed.

## Development

```bash
bin/setup       # bundle install
rake test       # run the (offline) test suite
```

## License

Released under the [MIT License](LICENSE.txt).
