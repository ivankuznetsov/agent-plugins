# feat: Answer Feedback (Skill Step 6)

## Overview

Update `skills/feedback/SKILL.md` Step 6 so Claude posts an explanatory reply comment via `add_annotation_comment` before calling `resolve_annotation`. Reviewers currently have no explanation of what was changed when an annotation is marked resolved — they have to open the code to verify. Posting the reply first leaves an audit trail they can read without leaving Screenote.

## Scope

This is a claude-screenote-only change. Both MCP tools the skill calls already exist in the Screenote Rails app:

- `add_annotation_comment` — takes `project_id`, `annotation_id`, `body`
- `resolve_annotation` — takes `project_id`, `annotation_id`, optional `comment`

No server changes are required for this PR. Emailing annotation authors when their feedback is addressed is a separate, follow-up concern tracked in the Screenote repo: see `screenote/plans/answer-feedback-digest-notifications.md` — which itself recommends a simple per-resolution `deliver_later` callback before considering the full digest design.

## Skill Step 6 Behavior

Replace the prior "Offer Next Steps" block with a detailed "Fix and Respond" workflow.

### Prior Behavior (Step 6, replaced by this PR)

```markdown
### Step 6: Offer Next Steps
- Address a specific annotation (and mark it resolved via `resolve_annotation` when done)
- Address all annotations one by one
- Take a new screenshot after making fixes
```

### New Behavior (Step 6)

```markdown
### Step 6: Fix and Respond

After presenting annotations, ask the user what to do. Then for each annotation being addressed:

1. **Fix the code** (if a code change is needed)
2. **Post a reply comment** explaining what was done:
   - Call `add_annotation_comment` with `project_id`, `annotation_id`, and a `body` describing the fix
   - Comment format: describe what was changed and where (file:line)
   - For "won't fix" / "by design" cases, explain the reasoning instead
3. **Resolve the annotation**:
   - Call `resolve_annotation` with `project_id`, `annotation_id`, and a brief `comment` (e.g., "Fixed" or "Won't fix — see reply")
4. **Handle failures by error class** — 401/403 stop and re-auth (do not resolve), 422 show and retry, 5xx/network retry once then stop; report `resolve_annotation` failures verbatim

Offer these options:
- Fix a specific annotation (and comment + resolve when done)
- Fix all annotations one by one (comment + resolve each)
- Reply without fixing (leave a comment explaining why, then resolve)
- Take a new screenshot after making fixes (`/screenote <url>`)
```

## Key Design Decisions

**Q: Why call both `add_annotation_comment` AND `resolve_annotation` instead of just using `resolve_annotation`'s `comment` param?**

They serve different purposes:
- `add_annotation_comment` → creates a visible **reply** in the annotation thread (action: `comment`). This is what the reviewer reads.
- `resolve_annotation` `comment` param → creates a **resolution note** (action: `resolved`). This is the audit trail entry.

**Q: What should the comment say?**

Template:
```
Fixed: [one-line summary]
Changed: [file:line] — [what was changed]
```

For non-code resolutions:
```
Won't fix: [reason]
```

**Q: What if the MCP call fails?**

Branch on error class — never blindly proceed:
- 401 / 403 on `add_annotation_comment` → stop, prompt re-auth, do NOT call `resolve_annotation` (resolving with no explanatory comment leaves a silent audit gap and the resolve will likely fail anyway).
- 422 validation → surface the error, adjust body, retry.
- 5xx / network → retry once; if still failing, stop.
- `resolve_annotation` failure → report the error verbatim, do not retry silently.

## Files to Change

| File | Change |
|---|---|
| `skills/feedback/SKILL.md` Step 6 | Replace "Offer Next Steps" with new "Fix and Respond" workflow |

## Acceptance Criteria

- [ ] Claude posts a reply comment (via `add_annotation_comment`) before resolving any annotation
- [ ] Both MCP calls pass `project_id` alongside `annotation_id`
- [ ] Reply comment describes what was changed (file, line, summary) or why it won't be fixed
- [ ] `resolve_annotation` is called after the comment is posted — except on 401/403 from the comment call, where Claude stops and prompts re-auth
- [ ] "Reply without fixing" option available for won't-fix cases

## QA

This repo has no Ruby test runner; Step 6 is LLM-instruction-following rather than executable code. Before shipping, walk through a manual QA session covering each error-class branch: 401 on comment, 422 on comment, 5xx then success on comment, `resolve_annotation` failure. Expected agent behavior is documented above — confirm by running `/feedback` against a test annotation and forcing each failure mode (e.g., via a temporary MCP stub or by editing the tool args).
