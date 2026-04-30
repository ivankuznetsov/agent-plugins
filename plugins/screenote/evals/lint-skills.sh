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
  refs=$(grep -oP '\(`skills/[^`]+`\)' "$skill_file" | grep -oP 'skills/[^`]+' || true)
  for ref in $refs; do
    if [ -f "$ref" ]; then
      pass "$skill_name cross-reference to $ref is valid"
    else
      fail "$skill_name cross-reference to $ref is broken"
    fi
  done
done

# Validate the canonical viewport table lives in screenote and contains every
# expected dimension. snapshot cross-references screenote for the table (see
# cross-reference check above), so we don't duplicate the assertion.
CANONICAL="$SKILLS_DIR/screenote/SKILL.md"
for val in "1280" "800" "768" "1024" "390" "844"; do
  if grep -q "$val" "$CANONICAL"; then
    pass "screenote contains viewport value $val"
  else
    fail "screenote missing viewport value $val"
  fi
done

# Validate MCP tool names are present in every skill that should reference them.
# Shape mirrors the FEEDBACK_TOOLS loop below: missing tool is a hard fail.
declare -A MCP_TOOL_SKILLS=(
  [list_projects]="screenote snapshot feedback"
  [create_project]="screenote"
  [create_multi_viewport_screenshot]="screenote snapshot"
)
for tool in "${!MCP_TOOL_SKILLS[@]}"; do
  for skill in ${MCP_TOOL_SKILLS[$tool]}; do
    skill_file="$SKILLS_DIR/$skill/SKILL.md"
    if grep -q "$tool" "$skill_file"; then
      pass "$skill references MCP tool '$tool'"
    else
      fail "$skill missing expected MCP tool '$tool'"
    fi
  done
done

# Guard against references to the retired create_screenshot_upload tool.
for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  skill_name=$(basename "$(dirname "$skill_file")")
  if grep -q "create_screenshot_upload" "$skill_file"; then
    fail "$skill_name still references retired tool 'create_screenshot_upload'"
  fi
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
