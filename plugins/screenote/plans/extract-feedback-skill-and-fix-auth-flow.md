# Extract Feedback Skill & Fix Auth/Cache Flow

**Type:** enhancement
**Date:** 2025-03-10

## Overview

Three related improvements to the claude-screenote plugin:

1. **Extract `/feedback` as a standalone skill** — move Feedback Mode out of `skills/screenote/SKILL.md` into `skills/feedback/SKILL.md` so users can invoke `/claude-screenote:feedback` (or `/feedback` shorthand)
2. **Check MCP auth before cached project** — call `list_projects` unconditionally at the start of the Project Cache section, before reading the cache file
3. **Suppress cached project announcement** — stop printing "Using cached Screenote project: **name** (delete...)" on every invocation; show the project name contextually in output instead

## Acceptance Criteria

- [ ] `skills/feedback/SKILL.md` exists and is invocable as `/claude-screenote:feedback`
- [ ] `/screenote feedback` still works (soft redirect message including fully qualified name)
- [ ] MCP auth is verified before any cache read (via `list_projects` at start of Project Cache)
- [ ] Cache hit does not print the verbose announcement message
- [ ] Project name appears in: feedback header, capture Step 5 ("Uploaded to **name**"), snapshot Step 8 summary
- [ ] Zero-state paths handled: no projects, no screenshots, no annotations
- [ ] References in screenote Step 5 and snapshot Step 8 updated to point to `/feedback`
- [ ] No cache format changes — existing `.claude/screenote-cache.json` files work as-is

---

## Implementation Plan

### File: `skills/feedback/SKILL.md` (CREATE)

New skill that cross-references screenote for cache/project logic (same pattern snapshot uses):

```markdown
---
name: feedback
description: Retrieve visual feedback and annotations from Screenote for the current project
user_invocable: true
argument: "[page-name or version]"
---

# Feedback — Retrieve Visual Annotations

You are executing the Feedback skill. This retrieves human annotations from Screenote so you can act on visual feedback.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Step 1: Resolve Project

Follow the **Project Cache** and **Pick a Project** procedure from the `/screenote` skill (`skills/screenote/SKILL.md`). The logic is identical: call `list_projects` first (auth gate), then check `.claude/screenote-cache.json`, match by local project name, or prompt the user.

If `list_projects` returned zero projects → say:
  "No Screenote projects found. Capture a page first with `/screenote <url>`." Stop.

## Step 2: Pick a Page and Version

Call `list_pages` with project_id.
- Zero pages → "No screenshots in this project yet. Use `/screenote <url>` to capture a page first." Stop.
- One page → use it automatically
- Multiple pages → show pages by name (with version count), let user pick

Call `list_screenshots` with project_id and page_id.
- One version → use it
- Multiple → show by title, let user pick

## Step 3: Fetch Annotations

Call `list_annotations` with project_id, screenshot_id, status: "open".

If zero annotations → say:
  "No open annotations for this screenshot. Open the annotate URL to add feedback, or check if annotations are marked as resolved." Include annotate_url if available. Stop.

## Step 4: Get Visual Context

For each annotation, call `get_annotation` to retrieve the cropped image of the annotated region.

## Step 5: Present Feedback

Header: "Feedback for **<project_name>** — <page_name> — <version_title>"

For each annotation, show:
- Type (point/region) with coordinates
- Author
- Comment text
- Cropped image

## Step 6: Offer Next Steps

- Address a specific annotation (resolve via `resolve_annotation` when done)
- Address all annotations one by one
- Take a new screenshot after fixes (`/screenote <url>`)
```

### File: `skills/screenote/SKILL.md` (EDIT)

**1. Update argument frontmatter** (line 5):
```
# Before
argument: "[mobile] [url-or-description] or 'feedback'"
# After
argument: "[mobile] [url-or-description]"
```

**2. Replace feedback mode detection** (line 18):
```
# Before
- If the argument starts with `feedback` → go to **Feedback Mode**
# After
- If the argument starts with `feedback` → tell the user: "Feedback has moved to its own command. Run `/feedback` (or `/claude-screenote:feedback`) instead." Stop.
```

**3. Rewrite Project Cache section** (lines 24-31) — inline auth-first by calling `list_projects` unconditionally before checking cache:
```markdown
## Project Cache

Call `list_projects` to verify the MCP connection and get the current project list. If the call fails with an auth error, tell the user to authorize the Screenote MCP server and stop.

Then check for a cached project selection:

1. Try to read `.claude/screenote-cache.json` (relative to cwd). If it exists and contains valid JSON with `project_id` and `project_name`, AND that `project_id` appears in the `list_projects` response, use that project and skip the "Pick a Project" step. Do not announce the cached selection.
2. If the file is missing, invalid, or the `project_id` is not in the `list_projects` response (stale cache), delete the cache file if it exists and proceed with the normal "Pick a Project" step below. After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.claude/screenote-cache.json` (create the `.claude/` directory if needed).
```

**4. Update Step 5** (line 100) — add project name and update feedback reference:
```
# Before
- Tell them to run `/screenote feedback` when they're done annotating
# After
- Say "Uploaded to **<project_name>**" in the success message
- Tell them to run `/feedback` when they're done annotating
```

**5. Remove Feedback Mode section** (lines 109-178): Delete the entire "## Feedback Mode" section and everything under it.

### File: `skills/snapshot/SKILL.md` (EDIT)

**1. Update feedback reference** (line 281):
```
# Before
Run /screenote feedback when ready.
# After
Run /feedback when ready.
```

**2. Add project name to summary** — in Step 8 summary template, add the project name:
```
# Add after "Viewport: Desktop (1440x900)"
Project: <project_name>
```

No other changes needed — snapshot cross-references screenote's Project Cache, so the auth-first and silent-cache changes propagate automatically.

---

## Files Changed Summary

| File | Action | Changes |
|---|---|---|
| `skills/feedback/SKILL.md` | CREATE | New feedback skill, cross-references screenote for cache logic |
| `skills/screenote/SKILL.md` | EDIT | Remove Feedback Mode, rewrite Project Cache (auth-first + silent), add project name to output, update references |
| `skills/snapshot/SKILL.md` | EDIT | Update feedback reference, add project name to summary |

---

## Edge Cases

| Scenario | Behavior |
|---|---|
| MCP not authorized | `list_projects` fails → OAuth instructions, stop |
| No projects | "No projects found, capture a page first" |
| No screenshots | "No screenshots yet, use `/screenote`" |
| No open annotations | "No open annotations, add some or check resolved" |
| Stale cache | `project_id` not in `list_projects` response → delete cache, re-prompt |
| `/screenote feedback` (old habit) | Redirect: "Run `/feedback` (or `/claude-screenote:feedback`) instead" |

## Notes

- **Naming:** `/feedback` is generic and may collide with other plugins. The fully qualified `/claude-screenote:feedback` always works. Accepted tradeoff.
- **Cross-reference vs duplication:** Feedback uses the same cross-reference pattern as snapshot (one line pointing to screenote's Project Cache). Consistent approach across all three skills.
- **Zero-state handling** in Steps 2-3 of the feedback skill is new behavior (not in current Feedback Mode). Explicitly added to prevent silent failures for first-time users.
