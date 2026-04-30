---
name: Expand evals/trigger-eval-set.json with new multi-viewport intents
description: Trigger eval set only covers pre-PR vocabulary (mobile keyword). New tablet/desktop keywords and multi-viewport intents are untested.
type: task
status: complete
priority: p2
issue_id: "009"
tags: [code-review, testing, evals]
dependencies: []
---

## Problem Statement

`evals/trigger-eval-set.json` exists specifically to validate that user queries trigger the right skill. Current content has:

- `"mobile screenshot of the signup form"` — still works post-PR, but no longer representative.
- No `tablet` or `desktop` keyword examples.
- No multi-viewport intent (e.g., "screenshot the dashboard at all viewports").
- No `/feedback` viewport filter intent.

## Findings

- Coverage gap, not a correctness gap. If a future PR changes mode detection, these cases aren't exercised.

## Proposed Solutions

### Option A (recommended) — Add 4–6 representative cases

```json
{"query": "tablet screenshot of /pricing", "should_trigger": "screenote"},
{"query": "desktop screenshot of /dashboard", "should_trigger": "screenote"},
{"query": "snapshot tablet http://localhost:3000", "should_trigger": "snapshot"},
{"query": "Screenshot the signup page at all viewports", "should_trigger": "screenote"},
{"query": "Show me the mobile feedback for /login", "should_trigger": "feedback"},
{"query": "desktop feedback", "should_trigger": "feedback"}
```

- Effort: Small.
- Risk: None.

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `evals/trigger-eval-set.json`

## Acceptance Criteria

- [ ] Tablet and desktop keyword examples present for both capture skills
- [ ] Multi-viewport natural-language intent present
- [ ] Viewport-filtered feedback intent present

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
