# Changelog

All notable changes to the Screenote plugin are documented here.

## [2.0.0] - 2026-07-14

### Changed

- Replaced the Screenote HTTP MCP data integration with the public `screenote` CLI.
- Made OAuth browser and device authorization the only documented login paths.
- Publish single-page and full-app captures through one resumable snapshot manifest.
- Read, comment on, and resolve annotations through CLI commands.

### Fixed

- Require every viewport variant of one logical screenshot to share the same page and title.
- Keep project selection repo-local and validate it against a fresh project list.
- Decode annotation crops to private local files instead of placing encoded image data in agent context.
- Make every agent-issued CLI command independent of shell state from earlier tool calls.
- Continue presenting remaining feedback when one annotation crop is unavailable.
- Validate plugin manifests, marketplace paths, skill frontmatter, and trigger fixtures in portable CI.

### Added

- Retained a pinned Browser Use adapter solely for local page capture, with exact viewport sizing, numeric-only settling metrics, exact scrolling, bounded file-backed screenshots, and ephemeral browser profiles.
- Added runtime smoke coverage for desktop, tablet, and mobile capture dimensions.

### Security

- Keep the Browser Use MCP server capture-only; projects, snapshots, annotations, comments, and resolution use the Screenote CLI and OAuth exclusively.

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
