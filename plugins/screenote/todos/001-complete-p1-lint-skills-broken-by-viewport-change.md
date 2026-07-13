---
name: Update evals/lint-skills.sh for new viewport values and MCP tool name
description: PR #5 renames the MCP tool and changes the canonical viewport set, but the structural linter still asserts the old values and now exits 1.
type: task
status: complete
priority: p1
issue_id: "001"
tags: [code-review, quality, ci, blocker]
dependencies: []
---

## Problem Statement

The structural linter `evals/lint-skills.sh` (added in commit `2b69051` specifically to catch drift between SKILL.md files) currently fails on the PR branch with **8 FAILs**:

```
FAIL: screenote missing viewport value 1440
FAIL: screenote missing viewport value 900
FAIL: screenote missing viewport value 393
FAIL: screenote missing viewport value 852
FAIL: snapshot missing viewport value 1440
FAIL: snapshot missing viewport value 900
FAIL: snapshot missing viewport value 393
FAIL: snapshot missing viewport value 852
```

The linter was added specifically to catch this class of drift, and the very first substantive change after it is the one that breaks it.

## Findings

- **Hardcoded old dimensions** (`evals/lint-skills.sh:50-53`):
  ```bash
  DESKTOP_W="1440"
  DESKTOP_H="900"
  MOBILE_W="393"
  MOBILE_H="852"
  ```
  New values per `skills/screenote/SKILL.md:28-30` and `skills/snapshot/SKILL.md:29-31`: desktop `1280×800`, tablet `768×1024`, mobile `390×844`. No tablet constants exist yet.

- **Stale MCP tool name** (`evals/lint-skills.sh:67`): `MCP_TOOLS="list_projects create_project create_screenshot_upload"`. The new PR renames this to `create_multi_viewport_screenshot`. The check is lenient (PASS-only, no FAIL branch when missing), so the linter passes over it silently — worse than failing loudly.

- **Structural bug in the MCP-tool check** (`evals/lint-skills.sh:67-74`): even after updating the tool name, the loop only emits `pass` when a tool is found and never calls `fail` on a miss. If a future PR drops `create_multi_viewport_screenshot` entirely, the linter will report green. The `FEEDBACK_TOOLS` loop immediately below (`:77-84`) does this correctly — `MCP_TOOLS` should mirror it.

## Proposed Solutions

### Option A (recommended) — Update constants and add tablet

Edit `evals/lint-skills.sh:50-53` to:
```bash
DESKTOP_W="1280"
DESKTOP_H="800"
TABLET_W="768"
TABLET_H="1024"
MOBILE_W="390"
MOBILE_H="844"
```
Add the tablet pair to the validation loop, and replace `create_screenshot_upload` with `create_multi_viewport_screenshot` at line 67. Add the missing `fail` branch so an absent tool name is a hard failure, not silent.

- Pros: minimal change, keeps the contract-checker approach.
- Cons: next viewport rename breaks it again (same bug).
- Effort: Small.
- Risk: None.

### Option B — Parse the viewport table out of the SKILL.md

Extract the pipe table from screenote SKILL.md and assert snapshot's matches. Makes the linter self-updating.

- Pros: eliminates the drift class entirely.
- Cons: more complex shell, more fragile parsing, less clear error messages.
- Effort: Medium.
- Risk: Low.

### Option C — Delete the viewport-value check

Trust the single-source-of-truth approach (see todo 004).

- Pros: zero maintenance.
- Cons: loses regression protection between the two capture SKILLs diverging.
- Effort: Small.
- Risk: Medium.

## Recommended Action

Ship **Option A** as part of this PR to unblock it. Revisit Option B or C when todo 004 (extract shared viewport table) lands.

## Technical Details

- **Affected files:** `evals/lint-skills.sh`
- **Verification:** `bash evals/lint-skills.sh` must exit 0 on the PR branch before merge.

## Acceptance Criteria

- [ ] `bash evals/lint-skills.sh` exits 0 on branch `feat/multi-viewport-capture`
- [ ] Tablet dimensions validated in both capture skills
- [ ] `create_multi_viewport_screenshot` presence validated in both capture skills
- [ ] `MCP_TOOLS` loop has an `else fail` branch so a missing tool reference is a hard failure (mirrors `FEEDBACK_TOOLS`)
- [ ] `create_screenshot_upload` string removed from the linter
- [ ] Bonus: wire the linter into CI (GitHub Actions) so this class of regression is caught pre-merge

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
- Linter commit: `2b69051 Add structural linting for SKILL.md files`
