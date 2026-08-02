# Changelog

All notable changes to the Screenote plugin are documented here.

## [Unreleased]

## [3.1.1] - 2026-08-02

### Fixed

- Publish all selected viewport captures through one resumable snapshot
  manifest so desktop, tablet, and mobile appear as variants of one version
  instead of separate desktop-labeled versions.
- Pass the snapshot processing wait explicitly, retain the complete manifest
  directory on timeouts or malformed terminal events, and exercise the
  manifest-backed path in protected integration tests.
- Accept explicit commit provenance for existing-image and capture publication
  outside a Git worktree.

## [3.1.0] - 2026-07-31

### Added

- Create an exactly named Screenote project during capture or snapshot setup
  when the user explicitly requests that mutation.

### Fixed

- Stop passing unsupported pagination flags to `page list` in the protected
  integration workflow.

## [3.0.2] - 2026-07-31

### Fixed

- Publish explicitly named existing PNG/JPEG files without requiring browser
  startup or viewport verification.
- Validate and copy user-owned images into a private mode-`0600` path before
  invoking the CLI, preserving source files and rejecting symlinks, malformed
  bytes, mismatched extensions, and files over 20 MB.

## [3.0.1] - 2026-07-20

### Fixed

- Declare the tested OpenClaw plugin API floor in generated package metadata
  so ClawHub can validate host compatibility.

## [3.0.0] - 2026-07-17

### Added

- Self-contained Pi and native OpenClaw packages for `screenote`, `snapshot`,
  and `feedback`.
- An argv-safe launcher with an explicit command allowlist and compatibility
  check against the OAuth-first CLI baseline.
- Offline JSON error, project-precedence, capture-recovery, and credential
  sentinel tests plus an opt-in protected live integration.

### Changed

- Capture now uses each host's native browser automation and uploads one
  private file at a time with `screenshot create`.
- Snapshot route discovery publishes repeated approved screenshot-create calls;
  feedback comments after fixes and leaves final resolution to the Screenote UI.
- Project selection follows explicit flag, environment, then CLI config.
- The CLI compatibility probe now checks every approved command-specific flag
  against the reachable merged Screenote CLI PR 6 baseline.

### Fixed

- Use the public CLI's real collection keys, top-level error shape, and
  pagination metadata in the shipped workflow contract and offline fixtures.
- Treat exit-zero non-JSON output, missing identifiers, malformed collections,
  and incomplete pagination as failures without inventing fallback ids.

### Removed

- The bundled browser transport configuration and runtime adapter.
- Bulk snapshot publication and automatic annotation resolution from agent
  workflows.

### Security

- Credentials remain in Screenote environment/config channels and are rejected
  as command arguments.
- Reject prompt-controlled endpoint and config overrides before the launcher
  invokes an authenticated Screenote CLI process.
- Successful temporary captures are deleted; failed captures remain mode
  `0600` in a private mode-`0700` directory with a reported recovery path.

## [2.0.1] - 2026-07-13

### Fixed

- Make bundled validation work from Codex's version-named plugin cache instead
  of assuming the install directory is named `screenote`.
- Skip repository-level marketplace checks when validating an installed plugin
  while retaining them in the source checkout.
- Add a regression fixture for the real Codex cache layout.
- Reject source checkouts with either repository marketplace catalog missing.

## [2.0.0] - 2026-07-13

### Changed

- Replaced the Screenote HTTP MCP data integration with the public `screenote` CLI.
- Made OAuth browser and device authorization the only documented login paths.
- Publish single-page and full-app captures through one resumable snapshot manifest.
- Read, comment on, and resolve annotations through CLI commands.

### Fixed

- Require every viewport variant of one logical screenshot to share the same page and title.
- Force instant scrolling so pages with smooth-scroll CSS still settle at deterministic offsets.
- Keep project selection repo-local and validate it against a fresh project list.
- Decode annotation crops to private local files instead of placing encoded image data in agent context.
- Make every agent-issued CLI command independent of shell state from earlier tool calls.
- Continue presenting remaining feedback when one annotation crop is unavailable.
- Shell-encode dynamic comment and resolution text as single argv values.
- Parse device authorization as a nonterminal JSON event followed by terminal output.
- Validate plugin manifests, marketplace paths, skill frontmatter, and trigger fixtures in portable CI.

### Added

- Retained a pinned Browser Use adapter solely for local page capture, with exact viewport sizing, numeric-only settling metrics, exact scrolling, bounded file-backed screenshots, and ephemeral browser profiles.
- Added runtime smoke coverage for desktop, tablet, and mobile capture dimensions.
- Run the pinned Browser Use runtime smoke in CI, including ephemeral-profile cleanup.

### Security

- Keep the Browser Use MCP server capture-only; projects, snapshots, annotations, comments, and resolution use the Screenote CLI and OAuth exclusively.
- Surface ephemeral browser-profile cleanup failures instead of silently leaving authenticated state on disk.

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
