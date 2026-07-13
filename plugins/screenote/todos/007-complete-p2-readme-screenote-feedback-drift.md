---
name: Fix /screenote feedback references in README (should be /feedback)
description: README still instructs users to run `/screenote feedback`, but screenote SKILL explicitly rejects that form and redirects to /feedback.
type: task
status: complete
priority: p2
issue_id: "007"
tags: [code-review, docs, user-facing]
dependencies: []
---

## Problem Statement

Two places in `README.md` tell users to run `/screenote feedback`:

- `README.md:31` — Quick Start code block "pull the feedback back":
  ```
  /screenote feedback
  ```
- `README.md:60` — "How It Works" ASCII diagram:
  ```
  │                            │── /screenote feedback ────►│
  ```

But `skills/screenote/SKILL.md:18` explicitly handles this and tells the user:

> "Feedback has moved to its own command. Run `/feedback` (or `/claude-screenote:feedback`) instead." Stop.

So the README is documenting a deprecated entry point as the primary flow.

**Note:** This drift was introduced in the earlier feedback-extraction PR (#3), not this PR. It is pre-existing. Including it here because this PR's README section is already under edit, so it's cheap to fix in the same change.

## Findings

- User-facing regression: a new user reading Quick Start runs `/screenote feedback`, hits the "moved" message, then has to figure out what to run instead.
- The "How It Works" diagram reinforces the wrong mental model.

## Proposed Solutions

### Option A (recommended) — Replace with /feedback

Change both references to `/feedback`. Update the diagram's arrow label to match.

- Effort: Small.
- Risk: None.

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `README.md`

## Acceptance Criteria

- [ ] `README.md:31` shows `/feedback` in the Quick Start
- [ ] `README.md:60` shows `/feedback` in the diagram
- [ ] No remaining occurrences of `/screenote feedback` in README

## Work Log

_(empty)_

## Resources

- PR that split feedback: https://github.com/ivankuznetsov/claude-screenote/pull/3
