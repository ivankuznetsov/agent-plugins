---
name: Disambiguate /feedback argument grammar (viewport keyword vs page name)
description: /feedback Step 3 overloads the single argument slot with an optional viewport keyword, conflicting with Step 2's page/version matcher and with the frontmatter declaration.
type: task
status: complete
priority: p1
issue_id: "002"
tags: [code-review, quality, agent-native, ux]
dependencies: []
---

## Problem Statement

`/feedback` now accepts an optional `desktop|tablet|mobile` viewport filter as part of the same argument string, but the argument grammar and the existing page-matching logic do not handle the collision.

Frontmatter (`skills/feedback/SKILL.md:5`):
```yaml
argument: "[page-name or version]"
```

Step 2 (`skills/feedback/SKILL.md:23`) runs the full argument as a case-insensitive match against page names and version titles. Step 3 (`skills/feedback/SKILL.md:39`) separately checks if the argument *starts with* a viewport keyword.

For `/feedback desktop login`:
- Step 2 tries to match "desktop login" against a page name — could collide with a literal page named "desktop" or "desktop login".
- Step 3 sees the viewport prefix and sets `viewport: desktop`, but the viewport token is never stripped before Step 2's matcher runs.

For `/feedback desktop` alone (no page hint):
- Step 2 matches the full argument "desktop" against page names. If any page is named "desktop", it auto-selects wrongly.

## Findings

- **Frontmatter lies** (`skills/feedback/SKILL.md:5`): no viewport token advertised.
- **Order-of-operations bug** (`skills/feedback/SKILL.md:23`, `:39`): Step 2 runs before the viewport keyword is stripped.
- **Documentation gap**: no example input shows the combined form.

## Proposed Solutions

### Option A (recommended) — Strip viewport prefix, update frontmatter

1. Update frontmatter to `argument: "[desktop|tablet|mobile] [page-name or version]"` so the agent sees the real grammar.
2. Add a pre-Step-1 normalization paragraph: "If the argument starts with `desktop`, `tablet`, or `mobile`, consume that token as the viewport filter and pass the remainder (possibly empty) as the page/version hint to Step 2."
3. Step 2's match is then unambiguous.

- Pros: small, local, preserves existing behavior intent.
- Cons: still overloads one arg slot — mild ambiguity if a page is literally named "desktop".
- Effort: Small.
- Risk: Low.

### Option B — Separate flags

Require `--viewport=desktop` or similar. Cleaner grammar, but breaks the lightweight keyword-prefix pattern used by `/screenote` and `/snapshot`.

- Pros: zero ambiguity.
- Cons: inconsistent with sibling skills; worse UX.
- Effort: Medium.
- Risk: Low.

## Recommended Action

Option A.

## Technical Details

- **Affected files:** `skills/feedback/SKILL.md`

## Acceptance Criteria

- [ ] Frontmatter `argument` reflects the optional viewport keyword
- [ ] SKILL explicitly describes viewport-stripping before page matching
- [ ] `/feedback desktop` treats "desktop" as a viewport filter, not a page name
- [ ] `/feedback desktop login` sets viewport=desktop AND matches page/version "login"

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
