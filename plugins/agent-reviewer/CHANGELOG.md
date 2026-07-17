# Changelog

## [0.3.0] - 2026-07-17

### Added

- Self-contained Pi and native OpenClaw packages generated from the canonical
  Agent Reviewer skill.
- Deterministic four-host package and public-entrypoint validation.

### Changed

- All hosts now run the same two-pass finding union by default, apply the same
  confidence gate, and support `--passes` and `--min-confidence` overrides.
- Claude command files are generated compatibility entrypoints that forward
  arguments unchanged to the canonical workflow.
