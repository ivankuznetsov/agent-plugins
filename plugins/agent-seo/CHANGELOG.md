# Changelog

## [2.0.1] - 2026-07-20

### Fixed

- Declare the tested OpenClaw plugin API floor in generated package metadata
  so ClawHub can validate host compatibility.

## [2.0.0] - 2026-07-18

### Changed

- The legacy `scrub` mode and Ruby CLI now perform a read-only formatting
  audit. They report format controls and em dashes without changing content or
  removing authorship/provenance signals.
- Existing-file edits require an explicit request for the exact path; editorial
  revisions otherwise return a preview or create a new file under `rewrites/`.
- Live analytics access now requires an explicit data workflow and declared
  source/scope, while credential setup defaults to protected storage outside
  the repository.
- ClawHub publication excludes development-only todos, Ruby tests, generated
  sample output, and validator reports from the installable bundle.

### Breaking

- `seo-scrub` no longer transforms or writes content. `--output`, cleaned-text
  stdout, legacy mutation counters, and in-place `scrub_file` behavior are
  removed. See `MIGRATION-2.0.md` for the audit result schema and upgrade path.

## [1.2.0] - 2026-07-17

### Added

- Self-contained Pi and native OpenClaw packages for every Agent SEO mode.
- Deterministic four-host package, resource, and public-entrypoint validation.

### Changed

- The canonical skill now owns all ten established workflows, optional
  Ruby/data prerequisites, partial-data behavior, and artifact locations.
- Existing `/seo:*` commands remain as generated argument-preserving adapters.

This vendored release must be published in the upstream Agent SEO repository
before the corresponding marketplace tag is created here.
