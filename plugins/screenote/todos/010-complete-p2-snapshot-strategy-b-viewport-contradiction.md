---
name: Fix contradiction in snapshot Strategy B viewport instruction
description: snapshot Step 4 Strategy B says to resize to "desktop or mobile, per Mode Detection", but Step 5 pins Strategy B to desktop-only. Agent sees contradictory instructions.
type: task
status: complete
priority: p2
issue_id: "010"
tags: [code-review, quality, agent-native]
dependencies: []
---

## Problem Statement

`skills/snapshot/SKILL.md:123`:
> 1. Set viewport via `browser_resize` (desktop or mobile, per Mode Detection)

`skills/snapshot/SKILL.md:173`:
> For Strategy B (runtime discovery) and authentication steps, resize the browser to **desktop (1280 × 800)** — those steps don't need per-viewport captures.

The first statement predates multi-viewport and was not updated. An agent reading sequentially either resizes incorrectly for Strategy B or spends tokens reconciling the contradiction.

**Concrete harm:** when the user runs `/snapshot mobile http://localhost:3000`, Mode Detection sets the viewport to mobile. Strategy B (Step 4) then runs runtime discovery at mobile width. Responsive apps commonly hide their primary nav behind a hamburger menu at that width, so `browser_snapshot` returns an accessibility tree without the main-nav links. Those routes get **silently omitted** from the snapshot — a correctness bug, not just a text contradiction. Step 5 on line 173 was written to prevent exactly this, but Step 4 reads sequentially and is followed first.

## Findings

- Order-of-reading bug: Step 4's inline instruction overrides the later Step 5 override.
- Real-world impact: mobile-keyword snapshots miss hamburger-hidden routes.

## Proposed Solutions

### Option A (recommended)

Change `skills/snapshot/SKILL.md:123` to:
> 1. Set viewport to **desktop (1280 × 800)** via `browser_resize` — discovery must run at desktop width so responsive hamburger menus don't hide links from the accessibility tree. Per-viewport captures happen later in Step 7.

Delete the forward-reference "(see Step 5) before any browser interaction" on line 121 since the instruction is now inline.

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `skills/snapshot/SKILL.md`

## Acceptance Criteria

- [ ] Strategy B uses desktop-only language inline (not via forward reference), matching Step 5
- [ ] Rationale about hamburger menus / responsive-nav hiding is stated at the point of use
- [ ] `/snapshot mobile` runs still discover the full route set before per-viewport capture

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
