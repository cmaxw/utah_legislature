# Changelog

## [0.1.0] - Unreleased

### Added
- `UtahLegislature::Client` — fetch legislators, committees, bill lists, and full
  bill detail (actions + versions + parsed text) from the Utah Legislature API.
- `UtahLegislature::Parser` — parse the `<leg>` bill XML into clean,
  section-delimited text, plus line-numbered HTML rendering.
- Value objects for legislators, committees, bills, actions, versions, and docs.
- Configurable throttling, timeouts, and logger.
