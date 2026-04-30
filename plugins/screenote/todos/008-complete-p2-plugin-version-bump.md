---
name: Bump plugin.json version for default-behavior change and MCP tool rename
description: PR changes default capture count (1→3), renames the MCP tool, and changes viewport dimensions, but `.claude-plugin/plugin.json` version is still 1.2.0.
type: task
status: complete
priority: p2
issue_id: "008"
tags: [code-review, release, versioning]
dependencies: []
---

## Problem Statement

`.claude-plugin/plugin.json:3`:
```json
"version": "1.2.0",
```

This PR changes:
- Default behavior of `/screenote` and `/snapshot` (single viewport → three viewports).
- Canonical viewport dimensions (`1440×900` → `1280×800`; `393×852` → `390×844`; tablet is new).
- MCP tool contract (`create_screenshot_upload` → `create_multi_viewport_screenshot`).

Consumers pinned to `1.2.0` upgrading without reading the changelog will see a 3× capture-time increase and potentially broken cached behavior.

## Findings

- No SemVer bump in this PR.

## Proposed Solutions

### Option A (recommended) — Minor bump to 1.3.0

Default behavior change is additive and preserves backward compatibility via `desktop|tablet|mobile` keyword opt-in. MCP tool rename is coordinated with server PR-3 (per PR description, this is blocked on server deploy).

- Pros: matches SemVer intent for "backward-compatible functionality."
- Cons: arguable that the tool rename is breaking.
- Effort: Small.

### Option B — Major bump to 2.0.0

Treat the MCP tool rename as a breaking contract.

- Pros: conservative.
- Cons: overstates user-visible breakage (users don't call the MCP tool directly).
- Effort: Small.

## Recommended Action

Option A — bump to `1.3.0`.

## Technical Details

- **Affected files:** `.claude-plugin/plugin.json`

## Acceptance Criteria

- [ ] `.claude-plugin/plugin.json` version is bumped

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
