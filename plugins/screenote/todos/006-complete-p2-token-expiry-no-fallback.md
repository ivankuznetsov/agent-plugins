---
name: Describe token-expiry fallback for 3× longer multi-viewport capture runs
description: Upload tokens live 5 minutes; serial multi-viewport × N-route capture can exceed that in /snapshot. Current skills specify no retry/regenerate path, risking silent partial uploads.
type: task
status: complete
priority: p2
issue_id: "006"
tags: [code-review, reliability, architecture]
dependencies: []
---

## Problem Statement

`skills/screenote/SKILL.md:105` states:

> **Important:** capture screenshots *after* requesting upload URLs so tokens don't expire mid-capture (they live for 5 minutes).

`skills/snapshot/SKILL.md:242` follows the same pattern. But multi-viewport mode makes capture ~3× slower, and /snapshot captures N routes in sequence. A 20-route run at ~3s/viewport is ~3 minutes — close to the limit for the last routes, and any slow-loading page pushes past.

When a token expires, the `curl PUT` returns 4xx. The SKILLs currently say nothing about detection or recovery — so the agent uploads half the batch, doesn't notice, and reports success.

## Findings

- No 4xx handling is specified in either capture step.
- `snapshot` already offers mid-batch-failure resume (line 268), but only for "API error, browser crash, network issue" — not token expiry specifically.

## Proposed Solutions

### Option A (recommended) — Add explicit retry-once-on-4xx instruction

After the `curl PUT` step in both skills, add:

> If `curl` reports a 4xx response (token expired or rejected), call `create_multi_viewport_screenshot` again for this route to get fresh URLs, then retry the PUT once. On second failure, record the route as failed and continue; include it in the summary.

- Pros: minimal; uses existing server primitive.
- Cons: relies on `create_multi_viewport_screenshot` being idempotent per `(project_id, page_name, title)` — confirm with server team or accept that retries produce duplicate screenshot rows.
- Effort: Small.
- Risk: Low.

### Option B — Request URLs per-viewport immediately before each PUT

Move the URL request inside the per-viewport loop. Tokens never age past one capture.

- Pros: token expiry becomes impossible in practice.
- Cons: Nx more round-trips; may break the current server contract (single Screenshot grouping via one `create_multi_viewport_screenshot` call).
- Effort: Medium.
- Risk: Medium.

## Recommended Action

Option A. Option B should be evaluated with the server team before adoption.

## Technical Details

- **Affected files:** `skills/screenote/SKILL.md`, `skills/snapshot/SKILL.md`

## Acceptance Criteria

- [ ] Both SKILLs describe detection of 4xx from the PUT
- [ ] Both SKILLs describe a single retry via a fresh `create_multi_viewport_screenshot` call
- [ ] Both SKILLs describe graceful degradation on second failure

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
