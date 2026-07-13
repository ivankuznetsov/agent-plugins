---
name: Extract Viewport Dimensions table and capture loop into a single canonical location
description: screenote and snapshot SKILLs duplicate the viewport table and the capture-upload loop verbatim. This is what caused the linter drift (todo 001) and will cause the next one.
type: task
status: complete
priority: p2
issue_id: "004"
tags: [code-review, quality, architecture]
dependencies: ["001"]
---

## Problem Statement

Two pieces of authoritative content are duplicated between `skills/screenote/SKILL.md` and `skills/snapshot/SKILL.md`:

1. **Viewport Dimensions table** (screenote:25-31, snapshot:26-32) — identical contents, easy to drift.
2. **Capture-and-upload loop** (screenote:107-123, snapshot:228-253) — nearly identical `browser_resize` → `browser_navigate` → `browser_wait_for` → `browser_take_screenshot` → `curl PUT` sequence.

`snapshot` already cross-references `screenote` for the project-picking procedure (snapshot:37), so the precedent exists.

## Findings

- The viewport duplication caused the linter drift that blocks this PR (todo 001).
- Next rename (Playwright adds a 2K viewport; S3 upload changes content-type; iPhone model bumps) will require editing both files and will silently drift if either is missed.

## Proposed Solutions

### Option A (recommended) — Canonical in screenote, cross-reference from snapshot

1. Keep Viewport Dimensions table in `skills/screenote/SKILL.md` only.
2. Replace snapshot's table with: "Use the viewport dimensions defined in `skills/screenote/SKILL.md` § Viewport Dimensions."
3. Extract the capture loop into a clearly labeled section in screenote; snapshot says "for each route, run the capture-and-upload loop from screenote against the `uploads` array."

- Pros: single source of truth; already how project-picking is handled.
- Cons: snapshot readers must follow a link for concrete steps.
- Effort: Small.
- Risk: Low.

### Option B — Move both to a new `skills/_shared.md`

- Pros: neither file is "primary."
- Cons: adds a file the linter and consumers need to know about.
- Effort: Small-Medium.
- Risk: Low.

### Option C — Treat viewports as a server-returned value

Drop the pixel table from prose entirely. `create_multi_viewport_screenshot` returns the pixels server-side, and the agent uses whatever comes back. Also relaxes the linter's coupling to specific numbers.

- Pros: zero drift possible.
- Cons: requires server-side response to include dimensions; larger contract change.
- Effort: Medium.
- Risk: Medium.

## Recommended Action

Option A for this PR. Option C is the right long-term move but should be its own PR after confirming with the Screenote server team.

## Technical Details

- **Affected files:** `skills/screenote/SKILL.md`, `skills/snapshot/SKILL.md`, `evals/lint-skills.sh` (simplification opportunity)

## Acceptance Criteria

- [ ] Viewport Dimensions table present in only one SKILL.md
- [ ] Capture-and-upload loop referenced rather than duplicated
- [ ] Linter still passes (or is simplified accordingly)

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
