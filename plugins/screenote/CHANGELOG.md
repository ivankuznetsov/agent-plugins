# Changelog

## [1.6.0] - 2026-07-13

### Added

- A pinned Browser Use adapter with exact viewport sizing, numeric-only page metrics, exact scrolling, bounded screenshot-to-file capture, and ephemeral browser profiles.
- Runtime MCP smoke coverage for desktop, tablet, and mobile dimensions plus file-backed PNG output.
- Structural lint coverage and negative drift tests for both Claude Code and Codex skill mirrors.

### Changed

- `/screenote` and `/snapshot` now use Browser Use instead of a host-provided Playwright MCP server.
- Full-page capture scrolls lazy-loaded pages with a 10-scroll traversal budget and caps output at 5000 px.

### Fixed

- Preflight browser capabilities before allocating remote Screenote upload records.
- Finalize exactly one route/viewport ledger row after capture and upload finish.
- Keep one batch ledger across all snapshot routes and close authenticated browser sessions on every exit path.
- Treat page-derived browser output as untrusted data and avoid page text during normal capture settling.
