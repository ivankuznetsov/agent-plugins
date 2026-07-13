#!/bin/bash
# Regression test: either product surface drifting must make lint fail.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d /tmp/screenote-lint-test-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

make_case() {
  local destination=$1
  mkdir -p "$destination/evals" "$destination/mcp"
  cp -R "$ROOT_DIR/skills" "$ROOT_DIR/codex-skills" "$destination/"
  cp "$ROOT_DIR/.mcp.json" "$destination/.mcp.json"
  cp "$ROOT_DIR/evals/lint-skills.sh" "$destination/evals/lint-skills.sh"
  cp "$ROOT_DIR/evals/browser-use-mcp-smoke.sh" "$destination/evals/browser-use-mcp-smoke.sh"
  cp "$ROOT_DIR/mcp/screenote_browser_use_mcp.py" "$destination/mcp/screenote_browser_use_mcp.py"
}

for root in skills codex-skills; do
  case_dir="$TMP_DIR/$root"
  make_case "$case_dir"
  target="$case_dir/$root/screenote/SKILL.md"
  awk '{gsub(/browser_screenshot_to_file/, "browser_screenshot_file_missing"); print}' \
    "$target" > "$target.tmp"
  mv "$target.tmp" "$target"

  if (cd "$case_dir" && bash evals/lint-skills.sh >/dev/null 2>&1); then
    echo "FAIL: lint accepted missing browser_screenshot_to_file in $root" >&2
    exit 1
  fi
  echo "PASS: lint rejects Browser Use drift in $root"
done
