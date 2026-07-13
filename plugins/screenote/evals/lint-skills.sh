#!/bin/bash
# Deterministic Screenote plugin contract checks.
# Requires: bash, grep, jq, python3

set -euo pipefail

cd "$(dirname "$0")/.."
PASS=0
FAIL=0

fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }

for skill in screenote snapshot feedback; do
  file="skills/$skill/SKILL.md"
  if [ -f "$file" ]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi

  for field in name description; do
    if grep -q "^${field}:" "$file"; then
      pass "$file has $field"
    else
      fail "$file missing $field"
    fi
  done

  if grep -q '^metadata:' "$file" && grep -q '^  argument:' "$file"; then
    pass "$skill frontmatter has metadata argument"
  else
    fail "$skill frontmatter is incomplete"
  fi
done

if [ -f references/cli.md ]; then
  pass "shared CLI contract exists"
else
  fail "shared CLI contract missing"
fi

for skill_file in skills/*/SKILL.md; do
  if grep -q '../../references/cli.md' "$skill_file"; then
    pass "$skill_file loads shared CLI contract"
  else
    fail "$skill_file does not load shared CLI contract"
  fi
done

for value in 1280 800 768 1024 390 844; do
  if grep -q "$value" skills/screenote/SKILL.md; then
    pass "capture skill contains viewport value $value"
  else
    fail "viewport value $value is missing from the capture skill"
  fi
done

CLI_CONTRACT=references/cli.md
for command in \
  'project list' \
  'project create --name' \
  'login --device' \
  'snapshot --manifest' \
  'page list' \
  'screenshot list --page' \
  'annotation list --screenshot' \
  'annotation get --annotation' \
  'comment add --annotation' \
  'annotation resolve --annotation'; do
  if grep -q -- "$command" "$CLI_CONTRACT"; then
    pass "CLI contract includes '$command'"
  else
    fail "CLI contract missing '$command'"
  fi
done

if grep -q -- '--limit 100' "$CLI_CONTRACT" &&
   grep -q -- '--offset 0' "$CLI_CONTRACT" &&
   grep -q 'pagination.total' "$CLI_CONTRACT"; then
  pass "CLI contract exhausts paginated feedback lists"
else
  fail "CLI contract does not exhaust paginated feedback lists"
fi

if grep -q 'must use exactly the same `page` and exactly the same `title`' "$CLI_CONTRACT" &&
   grep -q 'append `desktop`, `tablet`, `mobile`' "$CLI_CONTRACT"; then
  pass "CLI contract protects logical viewport grouping"
else
  fail "CLI contract does not protect logical viewport grouping"
fi

if grep -R -n -E '\$(SCREENOTE_BASE_URL|PROJECT_ID|PAGE_ID|SCREENSHOT_ID|ANNOTATION_ID|VIEWPORT|SCREENOTE_DIR|BODY|RESOLUTION)([^A-Z0-9_]|$)' \
  references skills >/dev/null 2>&1; then
  fail "agent-facing commands assume shell variables persist between tool calls"
else
  pass "agent-facing commands do not assume persistent shell variables"
fi

if grep -q 'do not share shell state' "$CLI_CONTRACT" &&
   grep -q 'screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}"' "$CLI_CONTRACT"; then
  pass "CLI contract makes the production base URL self-contained"
else
  fail "CLI contract does not make the production base URL self-contained"
fi

if grep -q '`crop_unavailable`' skills/feedback/SKILL.md &&
   grep -q -i 'continue with the remaining annotations' skills/feedback/SKILL.md; then
  pass "feedback degrades gracefully when one crop is unavailable"
else
  fail "feedback aborts when one crop is unavailable"
fi

if [ -e .mcp.json ]; then
  fail "legacy server config still exists"
else
  pass "legacy server config removed"
fi

ACTIVE_FILES=(
  README.md references skills .claude-plugin .codex-plugin
  ../../README.md ../../.claude-plugin/marketplace.json
  ../../plugins/agent-writing/agents/journalist.md
)
for forbidden in \
  'mcpServers' \
  '/mcp/messages' \
  'create_multi_viewport_screenshot' \
  'list_projects' \
  'screenote-skills' \
  'date --iso-8601' \
  'SCREENOTE_TOKEN' \
  '--token'; do
  if grep -R -n -i -- "$forbidden" "${ACTIVE_FILES[@]}" >/dev/null 2>&1; then
    fail "active plugin surface contains forbidden legacy contract '$forbidden'"
  else
    pass "active plugin surface excludes '$forbidden'"
  fi
done

for manifest in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  if jq -e '.version == "2.0.0"' "$manifest" >/dev/null; then
    pass "$manifest version is 2.0.0"
  else
    fail "$manifest version is not 2.0.0"
  fi
done

for marketplace in .claude-plugin/marketplace.json ../../.claude-plugin/marketplace.json; do
  if jq -e 'any(.plugins[]; .name == "screenote" and .version == "2.0.0")' "$marketplace" >/dev/null; then
    pass "$marketplace Screenote version is 2.0.0"
  else
    fail "$marketplace Screenote version is not 2.0.0"
  fi
done

if python3 evals/validate-plugin.py; then
  pass "portable plugin schema and frontmatter validation passed"
else
  fail "portable plugin schema or frontmatter validation failed"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
