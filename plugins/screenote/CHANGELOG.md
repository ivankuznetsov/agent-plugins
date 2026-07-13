# Changelog

All notable changes to the Screenote plugin are documented here.

## [2.0.0] - 2026-07-13

### Changed

- Replaced the Screenote server integration with the public `screenote` CLI.
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
