# Changelog

## [0.5.2] - 2026-07-20

### Fixed

- Declare the tested OpenClaw plugin API floor in generated package metadata
  so ClawHub can validate host compatibility.

## [0.5.1] - 2026-07-18

### Fixed

- Bundled voice and anti-example context is read-only by default. Editors report
  candidate anti-examples in their review and persist them only with explicit
  user opt-in.

## [0.5.0] - 2026-07-17

### Added

- Self-contained Pi and native OpenClaw packages generated from the canonical
  writing workflow.
- Deterministic four-host package and public-entrypoint validation.

### Changed

- Journalist grounding, writer/editor rivalry, five-round defaults,
  language/persona variants, and project-local artifact paths now have one
  canonical behavioral source.
- Existing `/write:*` commands remain as generated argument-preserving adapters.
