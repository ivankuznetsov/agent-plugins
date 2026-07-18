#!/usr/bin/env bash
# Deterministic checks for the Screenote JSON CLI contract.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [[ -f $1 ]] || fail "required file is missing: $1"
}

require_text() {
  grep -Fq -- "$2" "$1" || fail "$1 is missing required text: $2"
}

require_file references/cli.md
require_file references/workflows.json
require_file scripts/screenote-cli.sh
require_file scripts/screenote-approved-commands.sh
require_file scripts/screenote_flow.py
[[ -x scripts/screenote-cli.sh ]] || fail "scripts/screenote-cli.sh must be executable"
bash -n scripts/screenote-cli.sh scripts/screenote-approved-commands.sh

for skill in screenote snapshot feedback; do
  file="skills/$skill/SKILL.md"
  require_file "$file"
  require_text "$file" "name: $skill"
  require_text "$file" "../../references/cli.md"
  require_text "$file" "../../references/workflows.json"
done

for tuple in \
  'project list' \
  'page list' \
  'screenshot list' \
  'screenshot create' \
  'annotation list' \
  'annotation get' \
  'comment add'; do
  read -r noun verb <<<"$tuple"
  bash -c 'source scripts/screenote-approved-commands.sh; screenote_command_is_approved "$1" "$2"' _ "$noun" "$verb" ||
    fail "generated launcher allowlist is missing: $tuple"
  require_text references/cli.md "$tuple"
  require_text references/workflows.json "$tuple"
done

for required in \
  'SCREENOTE_PROJECT' \
  'missing_token' \
  'missing_project' \
  'Exit 3' \
  'HTTP(S)' \
  'mktemp -d' \
  '`0700`' \
  '`0600`'; do
  grep -R -Fq -- "$required" references skills || fail "shared workflow is missing: $required"
done

[[ ! -e .mcp.json ]] || fail ".mcp.json must not exist"

active_files=(references skills .claude-plugin/plugin.json .codex-plugin/plugin.json scripts/screenote-cli.sh scripts/screenote_flow.py)
for forbidden in \
  'mcpServers' \
  '/mcp/messages' \
  'screenote_browser_use_mcp' \
  'create_multi_viewport_screenshot' \
  'annotation resolve' \
  'project create' \
  'snapshot --manifest' \
  '--token'; do
  if grep -R -n -i -F -- "$forbidden" "${active_files[@]}" >/dev/null 2>&1; then
    fail "active plugin surface contains forbidden text: $forbidden"
  fi
done

python3 evals/validate-plugin.py
printf 'PASS: Screenote skills, launcher, manifests, and trigger fixtures are valid\n'
