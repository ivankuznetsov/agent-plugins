---
name: Move /snapshot credential-security note above the "ask for credentials" step
description: The security note about credentials-in-context appears after the step that asks the user how to log in. Users may have already pasted credentials by the time they read it.
type: task
status: complete
priority: p3
issue_id: "011"
tags: [code-review, security, ux]
dependencies: []
---

## Problem Statement

`skills/snapshot/SKILL.md:182-191` orders:

1. Line 182 — "Ask the user: 'Does this app require authentication? If so, how should I log in?'"
2. Line 188 — "Security note: Credentials provided for form login will be visible in the conversation context..."

An obedient agent asks for credentials first. The user pastes them. Only then does the skill prose mention the risk.

## Findings

- Ordering issue only — text content is fine.

## Proposed Solutions

### Option A (recommended)

Move the security note above line 182. Strengthen with: "Do not paste credentials into the chat. Prefer logging in manually in the browser before running /snapshot — the session cookies persist."

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `skills/snapshot/SKILL.md`

## Acceptance Criteria

- [ ] Security note rendered before the auth question
- [ ] Recommended alternative (pre-authenticated session) is the first option

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
