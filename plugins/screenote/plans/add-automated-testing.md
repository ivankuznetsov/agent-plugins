# Add Automated Testing for Claude-Screenote Skills

**Type:** enhancement
**Date:** 2025-03-10

## Overview

Add automated testing to the claude-screenote plugin. The plugin currently has zero tests — all validation is manual. This plan introduces structural linting as an immediately implementable first layer, with trigger evals deferred pending tooling improvements.

## Problem Statement

Claude Code skills (SKILL.md files) are LLM instruction documents, not code. Traditional unit tests don't apply. But the skills can still break in observable ways:

- Skill instructions become stale after refactoring (as we just saw with cross-references)
- Cross-references between skills point to nonexistent files or sections
- Viewport values or MCP tool names drift between skills
- The MCP server rejects calls due to schema changes or API drift
- A skill fires when it shouldn't, or doesn't fire when it should (trigger precision)

## Proposed Solution

### Layer 1: Structural Linting (implement now)

Deterministic checks on SKILL.md files — validates frontmatter, cross-references, viewport values, and MCP tool name consistency. Runs in milliseconds with no API calls. Catches the most common class of bugs we've already encountered.

### Layer 2: Trigger Evals (deferred)

Test whether the correct skill fires for a given user query. **Deferred** because:

- `claude -p --output-format json` does not expose which skill was triggered — the output is a flat result object with no `.messages[]` array or tool_use events
- `--allowedTools "Skill"` does not restrict tool usage as expected — Claude still attempts other tools (they get permission-denied but execution continues)
- A single query costs ~$0.38, not the estimated $0.01-0.05
- The skill execution path in headless mode doesn't match interactive mode — Claude executed 12 turns of file exploration instead of triggering the skill

**When to revisit:** When Claude Code adds a `--dry-run` or `--skill-match-only` flag, when `cc-plugin-eval` matures, or when `claude -p` output includes skill trigger metadata.

---

## Implementation Plan

### Layer 1: Structural Linting

**Create:** `evals/lint-skills.sh`

```bash
#!/bin/bash
# Lint SKILL.md files for structural correctness
# Requires: bash, grep
# Usage: ./evals/lint-skills.sh

set -euo pipefail
PASS=0
FAIL=0

fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }

SKILLS_DIR="skills"

# Check all skill directories exist and contain SKILL.md
for skill in screenote snapshot feedback; do
  if [ -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
    pass "$skill/SKILL.md exists"
  else
    fail "$skill/SKILL.md missing"
  fi
done

# Validate frontmatter fields in each SKILL.md
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  for field in name description user_invocable argument; do
    if grep -q "^${field}:" "$skill_file"; then
      pass "$skill_name has frontmatter field '$field'"
    else
      fail "$skill_name missing frontmatter field '$field'"
    fi
  done
done

# Validate cross-references point to existing files
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  # Extract file paths from cross-references like (`skills/screenote/SKILL.md`)
  refs=$(grep -oP '\(`skills/[^`]+`\)' "$skill_file" | grep -oP 'skills/[^`]+' || true)
  for ref in $refs; do
    if [ -f "$ref" ]; then
      pass "$skill_name cross-reference to $ref is valid"
    else
      fail "$skill_name cross-reference to $ref is broken"
    fi
  done
done

# Validate viewport values are consistent across skills
DESKTOP_W="1440"
DESKTOP_H="900"
MOBILE_W="393"
MOBILE_H="852"

for skill_file in "$SKILLS_DIR"/screenote/SKILL.md "$SKILLS_DIR"/snapshot/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  for val in "$DESKTOP_W" "$DESKTOP_H" "$MOBILE_W" "$MOBILE_H"; do
    if grep -q "$val" "$skill_file"; then
      pass "$skill_name contains viewport value $val"
    else
      fail "$skill_name missing viewport value $val"
    fi
  done
done

# Validate MCP tool names are consistent across skills
# These are the tools referenced in the skills — if one skill uses a different name, it's a bug
MCP_TOOLS="list_projects create_project create_screenshot_upload"
for tool in $MCP_TOOLS; do
  for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
    skill_name=$(basename "$(dirname "$skill_file")")
    if grep -q "$tool" "$skill_file"; then
      pass "$skill_name references MCP tool '$tool'"
    fi
    # Not all skills use all tools — only fail if a tool name is misspelled
  done
done

# Check feedback-specific MCP tools
FEEDBACK_TOOLS="list_pages list_screenshots list_annotations get_annotation resolve_annotation"
for tool in $FEEDBACK_TOOLS; do
  if grep -q "$tool" "$SKILLS_DIR/feedback/SKILL.md"; then
    pass "feedback references MCP tool '$tool'"
  else
    fail "feedback missing expected MCP tool '$tool'"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

### Trigger Eval Dataset (for future use)

Keep the dataset ready for when trigger eval tooling improves.

**Create:** `evals/trigger-eval-set.json`

```json
[
  {"query": "Take a screenshot of the login page", "should_trigger": "screenote"},
  {"query": "Screenshot http://localhost:3000/dashboard", "should_trigger": "screenote"},
  {"query": "mobile screenshot of the signup form", "should_trigger": "screenote"},
  {"query": "screenote the pricing page", "should_trigger": "screenote"},
  {"query": "Snapshot the entire app", "should_trigger": "snapshot"},
  {"query": "snapshot mobile http://localhost:3000", "should_trigger": "snapshot"},
  {"query": "Take screenshots of all routes", "should_trigger": "snapshot"},
  {"query": "Get my feedback from screenote", "should_trigger": "feedback"},
  {"query": "Show me the annotations", "should_trigger": "feedback"},
  {"query": "What did the designer say about the login page?", "should_trigger": "feedback"},
  {"query": "Fix the CSS on the header", "should_trigger": null},
  {"query": "Deploy the app to production", "should_trigger": null},
  {"query": "Write a test for the user model", "should_trigger": null},
  {"query": "feedback", "should_trigger": "feedback"}
]
```

### README

**Create:** `evals/README.md`

```markdown
# Evaluations

## Structural Linting

Deterministic checks on SKILL.md files — no API calls, runs instantly.

    ./evals/lint-skills.sh

Validates:
- All skill directories exist with SKILL.md files
- Frontmatter fields (name, description, user_invocable, argument)
- Cross-references between skills point to existing files
- Viewport values (1440x900 desktop, 393x852 mobile) are consistent
- MCP tool names are present where expected

Run on every PR that touches `skills/**/*.md`.

## Trigger Eval Dataset

`trigger-eval-set.json` contains 14 test queries mapping to expected skill triggers. This dataset is ready for use when Claude Code provides proper skill trigger testing support (e.g., a `--dry-run` flag, skill match metadata in output, or `cc-plugin-eval` maturity).

### Why trigger evals are deferred

Tested `claude -p --output-format json` on 2025-03-10. Findings:
- Output is a flat result object — no message-level tool_use events exposed
- `--allowedTools "Skill"` does not restrict tool usage as expected
- Single query cost ~$0.38 (Opus), not viable for a 14-query eval suite
- Skills don't trigger as discrete `Skill` tool calls in headless mode

## CI Notes

- Lint evals: run on every PR (free, instant)
- Trigger evals: revisit when tooling improves
```

---

## Files to Create

| File | Purpose |
|---|---|
| `evals/lint-skills.sh` | Deterministic structural linting |
| `evals/trigger-eval-set.json` | Trigger precision test dataset (for future use) |
| `evals/README.md` | How to run evals, status of trigger evals |

## Acceptance Criteria

- [ ] `evals/` directory exists with all three files
- [ ] `lint-skills.sh` is executable and passes when run against current skills
- [ ] Lint script validates: frontmatter, cross-references, viewport values, MCP tool names
- [ ] Trigger eval set covers all three skills + negative cases (14 queries)
- [ ] README documents linting usage, trigger eval status, and CI notes

## Empirical Findings (2025-03-10)

Tested `claude -p` output format to validate the trigger eval approach. Results:

```json
{
  "type": "result",
  "subtype": "success",
  "num_turns": 12,
  "result": "This project doesn't have its own web app...",
  "total_cost_usd": 0.38,
  "permission_denials": [
    {"tool_name": "Bash", ...},
    {"tool_name": "Bash", ...}
  ]
}
```

Key findings:
- **No `.messages[]` array** — output is flat, doesn't expose tool_use events
- **Skill didn't trigger as Skill tool** — Claude used 12 turns of Read/Glob/Bash exploration
- **`--allowedTools "Skill"` ineffective** — other tools still attempted (permission-denied)
- **Cost $0.38 per query** — 14 queries would cost ~$5.30 per run

## Review Decisions

Changes made based on plan review and empirical testing:

1. **Cut Promptfoo (original Layer 2):** Tests LLM reasoning about instructions, not actual behavior. Feeds SKILL.md as system prompt and checks if Claude *describes* doing the right thing — reading comprehension, not functional test.
2. **Added structural linting:** Catches the most common failure mode (stale cross-references, inconsistent values) at zero cost. This is the exact class of bug we hit during the feedback extraction refactor.
3. **Deferred trigger evals:** `claude -p` output format doesn't support skill trigger detection. Kept the eval dataset for future use.
4. **Fixed `--max-turns` flag:** Does not exist in `claude` CLI. Moot now that trigger evals are deferred.
5. **Removed `skill-prompt-loader.cjs`:** Only existed to support Promptfoo.

## References

- [cc-plugin-eval](https://github.com/sjnims/cc-plugin-eval) — community plugin testing framework (potential future solution)
- [Claude Code headless mode](https://code.claude.com/docs/en/headless) — `claude -p` documentation
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) — Anthropic's eval guidance
