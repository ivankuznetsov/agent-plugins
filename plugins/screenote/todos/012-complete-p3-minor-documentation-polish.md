---
name: Minor documentation polish (argument optionality, single-viewport README examples, feedback labels)
description: Batch of small wording/consistency nits found during review.
type: task
status: complete
priority: p3
issue_id: "012"
tags: [code-review, docs, quality]
dependencies: []
---

## Problem Statement

Collecting low-severity polish items from the review into one todo to avoid clutter.

## Findings

1. **Argument optionality unclear** (`skills/screenote/SKILL.md:5`, `skills/snapshot/SKILL.md:5`):
   `argument: "[desktop|tablet|mobile] [url-or-description]"` reads both brackets as optional. The URL is usually required; the viewport prefix is optional. Prefer something like `argument: "[desktop|tablet|mobile]? <url-or-description>"` or a follow-up comment.

2. **README single-viewport example only shows `mobile`** (`README.md:103`):
   > "Use `desktop`, `tablet`, or `mobile` for single-viewport: `/snapshot mobile http://localhost:3000`"
   Show a `desktop` or `tablet` example for symmetry.

3. **Feedback viewport label casing** (`skills/feedback/SKILL.md:52,55`):
   Uses "Desktop / Tablet / Mobile" plus "iPad" parenthetical, while capture SKILLs use lowercase `desktop/tablet/mobile` and "iPad mini". Pick one.

4. **Speculative commentary** (`skills/screenote/SKILL.md:105,119`; `skills/snapshot/SKILL.md:253-254`):
   "tokens live for 5 minutes" and "~3× slower at ~3s/viewport for a 20-route app" age badly and leak implementation detail. If not load-bearing, shorten or remove.

5. **`page_id` purpose unstated** (`skills/screenote/SKILL.md:94`):
   Response shape shows `page_id` but nothing downstream uses it in screenote. One line clarifying "only `screenshot_id` and `annotate_url` are used downstream" helps agent focus.

6. **Cleanup block hardcodes 3 filenames** (`skills/screenote/SKILL.md:135-137`):
   Even in single-viewport mode, all three `rm -f` targets are listed. Tie to todo 005 (mktemp fix): `rm -rf "$SCREENOTE_DIR"`.

## Proposed Solutions

Single pass through the files addressing each item. Effort: Small.

## Recommended Action

Batch-fix after the P1/P2 items land.

## Technical Details

- **Affected files:** `skills/screenote/SKILL.md`, `skills/snapshot/SKILL.md`, `skills/feedback/SKILL.md`, `README.md`

## Acceptance Criteria

- [ ] Item 1 addressed
- [ ] Item 2 addressed
- [ ] Item 3 addressed
- [ ] Item 4 addressed
- [ ] Item 5 addressed
- [ ] Item 6 addressed (or tracked under todo 005)

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
