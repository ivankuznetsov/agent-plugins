#!/bin/bash
# Lint Claude Code and Codex skill mirrors for structural and capture-contract parity.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

PASS=0
FAIL=0
SKILL_ROOTS=(skills codex-skills)

fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }

require_text() {
  local file=$1
  local text=$2
  local label=$3
  if grep -Fq "$text" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

reject_text() {
  local file=$1
  local text=$2
  local label=$3
  if grep -Fq "$text" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

for root in "${SKILL_ROOTS[@]}"; do
  for skill in screenote snapshot feedback; do
    file="$root/$skill/SKILL.md"
    if [ -f "$file" ]; then
      pass "$file exists"
    else
      fail "$file missing"
    fi
  done

  for skill_file in "$root"/*/SKILL.md; do
    skill_name=$(basename "$(dirname "$skill_file")")
    require_text "$skill_file" "name:" "$root/$skill_name has name frontmatter"
    require_text "$skill_file" "description:" "$root/$skill_name has description frontmatter"
    require_text "$skill_file" "argument:" "$root/$skill_name has argument frontmatter"
    if [ "$root" = "skills" ]; then
      require_text "$skill_file" "user_invocable:" "$root/$skill_name has user_invocable frontmatter"
    else
      require_text "$skill_file" "metadata:" "$root/$skill_name has metadata frontmatter"
    fi

    refs=$(grep -oE '\(`(skills|codex-skills)/[^`]+`\)' "$skill_file" | grep -oE '(skills|codex-skills)/[^`]+' || true)
    for ref in $refs; do
      if [ -f "$ref" ]; then
        pass "$root/$skill_name cross-reference to $ref is valid"
      else
        fail "$root/$skill_name cross-reference to $ref is broken"
      fi
    done
  done

  canonical="$root/screenote/SKILL.md"
  for value in 1280 800 768 1024 390 844; do
    require_text "$canonical" "$value" "$root/screenote contains viewport value $value"
  done

  declare -A screenote_tools=(
    [list_projects]="screenote snapshot feedback"
    [create_project]="screenote"
    [create_multi_viewport_screenshot]="screenote snapshot"
  )
  for tool in "${!screenote_tools[@]}"; do
    for skill in ${screenote_tools[$tool]}; do
      require_text "$root/$skill/SKILL.md" "$tool" "$root/$skill references Screenote tool $tool"
    done
  done
  unset screenote_tools

  for skill_file in "$root"/*/SKILL.md; do
    reject_text "$skill_file" "create_screenshot_upload" "$skill_file omits retired create_screenshot_upload"
  done

  for tool in browser_navigate browser_set_viewport browser_page_metrics browser_scroll_to browser_screenshot_to_file browser_close_all; do
    require_text "$root/screenote/SKILL.md" "$tool" "$root/screenote references Browser Use tool $tool"
  done
  for tool in browser_navigate browser_get_state browser_get_html browser_type browser_click browser_set_viewport browser_page_metrics browser_scroll_to browser_screenshot_to_file browser_close_all; do
    require_text "$root/snapshot/SKILL.md" "$tool" "$root/snapshot references Browser Use tool $tool"
  done

  for field in route viewport output cap_fired unsettled_poll unverified_scroll_top uploaded failed failure_reason; do
    require_text "$root/screenote/SKILL.md" "$field" "$root/screenote terminal ledger includes $field"
  done
  require_text "$root/screenote/SKILL.md" "exactly one final JSON object" "$root/screenote finalizes one status row"
  require_text "$root/snapshot/SKILL.md" "batch-scoped" "$root/snapshot owns a batch-scoped ledger"
  require_text "$root/snapshot/SKILL.md" "route=<route_path>" "$root/snapshot records route in the ledger"
  require_text "$root/snapshot/SKILL.md" "untrusted data" "$root/snapshot declares the page trust boundary"

  reject_text "$root/screenote/SKILL.md" "no viewport-sizing tool" "$root/screenote omits obsolete viewport limitation"
  reject_text "$root/screenote/SKILL.md" "base64 -d" "$root/screenote omits MCP image decoding"
  reject_text "$root/screenote/SKILL.md" "tile-001" "$root/screenote omits overlapping tile fallback"
done

for tool in list_pages list_screenshots list_annotations get_annotation resolve_annotation; do
  for root in "${SKILL_ROOTS[@]}"; do
    require_text "$root/feedback/SKILL.md" "$tool" "$root/feedback references Screenote tool $tool"
  done
done

require_text .mcp.json "browser-use[cli]==0.13.4" ".mcp.json pins Browser Use 0.13.4"
require_text evals/browser-use-mcp-smoke.sh "browser-use[cli]==0.13.4" "smoke expects Browser Use 0.13.4"
require_text .mcp.json "mcp==1.26.0" ".mcp.json pins MCP 1.26.0"
require_text evals/browser-use-mcp-smoke.sh "mcp==1.26.0" "smoke uses MCP 1.26.0"
require_text .mcp.json "screenote_browser_use_mcp.py" ".mcp.json launches the bundled adapter"

if [ -f mcp/screenote_browser_use_mcp.py ]; then
  pass "Browser Use adapter exists"
else
  fail "Browser Use adapter missing"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
