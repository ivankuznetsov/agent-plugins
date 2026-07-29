#!/bin/bash
# Deterministic Screenote CLI and capture-adapter contract checks.
# Requires: bash, grep, jq, python3

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

PASS=0
FAIL=0

fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }

require_text() {
  local file=$1
  local text=$2
  local label=$3
  if grep -Fq -- "$text" "$file"; then pass "$label"; else fail "$label"; fi
}

reject_text() {
  local text=$1
  local label=$2
  shift 2
  if grep -R -n -i -F -- "$text" "$@" >/dev/null 2>&1; then
    fail "$label"
  else
    pass "$label"
  fi
}

for skill in screenote snapshot feedback; do
  file="skills/$skill/SKILL.md"
  if [ -f "$file" ]; then pass "$file exists"; else fail "$file missing"; continue; fi
  require_text "$file" "name: $skill" "$skill name frontmatter is correct"
  require_text "$file" "description:" "$skill has description frontmatter"
  require_text "$file" "metadata:" "$skill has shared metadata frontmatter"
  require_text "$file" "  argument:" "$skill has metadata.argument"
  require_text "$file" "../../references/cli.md" "$skill loads the shared contract"
done

if [ -e codex-skills ]; then
  fail "obsolete Codex skill mirrors still exist"
else
  pass "Claude Code and Codex share one skill surface"
fi

CLI_CONTRACT=references/cli.md
if [ -f "$CLI_CONTRACT" ]; then pass "shared CLI contract exists"; else fail "shared CLI contract missing"; fi

for value in 1280 800 768 1024 390 844; do
  require_text skills/screenote/SKILL.md "$value" "canonical capture skill contains $value"
done

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
  require_text "$CLI_CONTRACT" "$command" "CLI contract includes '$command'"
done

require_text "$CLI_CONTRACT" '--limit 100' "feedback lists use a bounded page size"
require_text "$CLI_CONTRACT" '--offset 0' "feedback pagination starts explicitly"
require_text "$CLI_CONTRACT" 'pagination.total' "feedback pagination exhausts the server total"
require_text "$CLI_CONTRACT" 'must use exactly the same `page` and exactly the same `title`' "viewport variants share one logical screenshot"
require_text "$CLI_CONTRACT" 'append `desktop`, `tablet`, `mobile`' "device labels stay out of logical titles"
require_text "$CLI_CONTRACT" 'do not share shell state' "agent commands are independent across tool calls"
require_text "$CLI_CONTRACT" 'command runner accepts an argument array' "dynamic values use argument-array execution when available"
require_text "$CLI_CONTRACT" 'encode every value as one POSIX' "dynamic values require shell-safe encoding"
require_text "$CLI_CONTRACT" 'Never place raw dynamic' "dynamic text is never interpolated into shell source"
require_text "$CLI_CONTRACT" '--body <one-shell-quoted-explanatory-reply-argument>' "comment bodies are passed as one shell-safe argument"
require_text "$CLI_CONTRACT" '--comment <one-shell-quoted-resolution-note-argument>' "resolution notes are passed as one shell-safe argument"
require_text "$CLI_CONTRACT" 'screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}"' "CLI commands honor the explicit base URL"
require_text "$CLI_CONTRACT" 'stdout and stderr as separate JSON Lines streams' "device OAuth documents its streaming output"
require_text "$CLI_CONTRACT" 'event as failure; use the process exit status' "device OAuth distinguishes authorization from terminal output"
require_text "$CLI_CONTRACT" 'command runner merges the two streams' "device OAuth supports merged-output command runners"
require_text "$CLI_CONTRACT" 'Existing-image publication' "CLI contract separates existing-image publication from browser capture"
require_text "$CLI_CONTRACT" 'does not start Browser Use or call any `browser_*` tool' "existing images bypass the browser runtime"
require_text skills/screenote/SKILL.md '## Existing-image mode' "screenote supports explicit local image files"
require_text skills/screenote/SKILL.md 'Skip Browser Use discovery, preflight, navigation, and capture entirely.' "existing-image mode cannot be blocked by browser startup"
require_text skills/feedback/SKILL.md '`crop_unavailable`' "feedback handles unavailable crops"
require_text skills/feedback/SKILL.md 'Continue with the remaining annotations' "one missing crop does not hide other feedback"

for tool in browser_navigate browser_set_viewport browser_page_metrics browser_scroll_to browser_screenshot_to_file browser_close_all; do
  require_text "$CLI_CONTRACT" "$tool" "capture contract requires $tool"
done
for tool in browser_get_state browser_get_html browser_type browser_click; do
  require_text skills/snapshot/SKILL.md "$tool" "snapshot documents $tool"
done
for text in \
  '15 polls' \
  '10 downward scrolls' \
  'max_height=5000' \
  'numeric values returned by `browser_page_metrics`' \
  'untrusted data' \
  'exactly one terminal JSON object' \
  'Close the browser after all files are captured'; do
  require_text "$CLI_CONTRACT" "$text" "capture contract includes '$text'"
done
for field in route viewport output cap_fired unsettled_poll unverified_scroll_top captured failed failure_reason; do
  require_text "$CLI_CONTRACT" "$field" "capture ledger includes $field"
done

for file in .mcp.json mcp/screenote_browser_use_mcp.py evals/browser-use-mcp-smoke.sh evals/browser-use-mcp-surface.md; do
  if [ -f "$file" ]; then pass "$file exists"; else fail "$file missing"; fi
done

if jq -e '
  (keys == ["mcpServers"]) and
  ((.mcpServers | keys) == ["browser-use"]) and
  (.mcpServers["browser-use"].type == "stdio") and
  (.mcpServers["browser-use"].command == "uv") and
  (.mcpServers["browser-use"].cwd == ".") and
  (.mcpServers["browser-use"].env.BROWSER_USE_HEADLESS == "false") and
  (.mcpServers["browser-use"] | has("url") | not) and
  (.mcpServers["browser-use"].args | index("browser-use[cli]==0.13.4") != null) and
  (.mcpServers["browser-use"].args | index("mcp==1.26.0") != null) and
  (.mcpServers["browser-use"].args | any(contains("screenote_browser_use_mcp.py")))
' .mcp.json >/dev/null; then
  pass ".mcp.json exposes only the pinned local Browser Use adapter"
else
  fail ".mcp.json is not the exact capture-only Browser Use configuration"
fi

for pin in 'browser-use[cli]==0.13.4' 'mcp==1.26.0'; do
  require_text .mcp.json "$pin" ".mcp.json contains $pin"
  require_text evals/browser-use-mcp-smoke.sh "$pin" "browser smoke expects $pin"
done
for method in browser_set_viewport browser_page_metrics browser_scroll_to browser_screenshot_to_file; do
  require_text mcp/screenote_browser_use_mcp.py "$method" "adapter implements $method"
done
require_text mcp/screenote_browser_use_mcp.py '_close_all_sessions' "adapter cleans its ephemeral profile when sessions close"
require_text mcp/screenote_browser_use_mcp.py 'BROWSER_USE_EXECUTABLE_PATH' "adapter supports an explicit CI browser binary"
require_text evals/browser-use-mcp-smoke.sh 'browser_close_all' "browser smoke verifies close-all cleanup"
require_text evals/browser-use-mcp-smoke.sh 'BROWSER_USE_EXECUTABLE_PATH' "browser smoke forwards an explicit CI browser binary"

PLUGIN_VERSION=$(jq -r '.version // empty' .codex-plugin/plugin.json)
if jq -e '.skills == "./skills/" and .mcpServers == "./.mcp.json" and (has("apps") | not)' .codex-plugin/plugin.json >/dev/null; then
  pass "Codex manifest loads shared skills and capture-only MCP config"
else
  fail "Codex manifest component paths are incorrect"
fi

for manifest in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  if jq -e --arg version "$PLUGIN_VERSION" '.version == $version' "$manifest" >/dev/null; then pass "$manifest version is $PLUGIN_VERSION"; else fail "$manifest version does not match $PLUGIN_VERSION"; fi
done
MARKETPLACES=(.claude-plugin/marketplace.json)
if [ -f ../../.claude-plugin/marketplace.json ]; then
  MARKETPLACES+=(../../.claude-plugin/marketplace.json)
fi
for marketplace in "${MARKETPLACES[@]}"; do
  if jq -e --arg version "$PLUGIN_VERSION" 'any(.plugins[]; .name == "screenote" and .version == $version)' "$marketplace" >/dev/null; then
    pass "$marketplace Screenote version is $PLUGIN_VERSION"
  else
    fail "$marketplace Screenote version does not match $PLUGIN_VERSION"
  fi
done

ACTIVE_FILES=(README.md references skills .claude-plugin .codex-plugin)
if [ -f ../../.claude-plugin/marketplace.json ]; then
  ACTIVE_FILES+=(../../.claude-plugin/marketplace.json)
fi
for forbidden in \
  '/mcp/messages' \
  'create_multi_viewport_screenshot' \
  'list_projects' \
  'upload_url' \
  'SCREENOTE_URL' \
  'SCREENOTE_TOKEN' \
  '--token' \
  'screenote-skills' \
  'date --iso-8601' \
  'curl'; do
  reject_text "$forbidden" "active plugin surface excludes legacy Screenote transport '$forbidden'" "${ACTIVE_FILES[@]}"
done

if python3 evals/validate-plugin.py; then
  pass "portable plugin validation passed"
else
  fail "portable plugin validation failed"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
