#!/bin/bash
# Regression fixtures: capture-contract drift and Screenote MCP transport must fail lint.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d /tmp/screenote-lint-test-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

make_case() {
  local destination=$1
  local repo_root
  repo_root=$(dirname "$(dirname "$destination")")
  mkdir -p "$destination/evals" "$destination/mcp" "$destination/references" \
    "$destination/.claude-plugin" "$destination/.codex-plugin" \
    "$repo_root/.claude-plugin" "$repo_root/.agents/plugins"
  cp -R "$ROOT_DIR/skills" "$destination/"
  cp "$ROOT_DIR/references/cli.md" "$destination/references/cli.md"
  cp "$ROOT_DIR/.mcp.json" "$destination/.mcp.json"
  cp "$ROOT_DIR/README.md" "$destination/README.md"
  cp "$ROOT_DIR/.claude-plugin/plugin.json" "$destination/.claude-plugin/plugin.json"
  cp "$ROOT_DIR/.codex-plugin/plugin.json" "$destination/.codex-plugin/plugin.json"
  cp "$ROOT_DIR/.claude-plugin/marketplace.json" "$destination/.claude-plugin/marketplace.json"
  cp "$ROOT_DIR/evals/lint-skills.sh" "$destination/evals/lint-skills.sh"
  cp "$ROOT_DIR/evals/validate-plugin.py" "$destination/evals/validate-plugin.py"
  cp "$ROOT_DIR/evals/trigger-eval-set.json" "$destination/evals/trigger-eval-set.json"
  cp "$ROOT_DIR/evals/browser-use-mcp-smoke.sh" "$destination/evals/browser-use-mcp-smoke.sh"
  cp "$ROOT_DIR/evals/browser-use-mcp-surface.md" "$destination/evals/browser-use-mcp-surface.md"
  cp "$ROOT_DIR/mcp/screenote_browser_use_mcp.py" "$destination/mcp/screenote_browser_use_mcp.py"
  cp "$ROOT_DIR/../../.claude-plugin/marketplace.json" "$repo_root/.claude-plugin/marketplace.json"
  cp "$ROOT_DIR/../../.agents/plugins/marketplace.json" "$repo_root/.agents/plugins/marketplace.json"
  python3 - "$repo_root/.claude-plugin/marketplace.json" "$repo_root/.agents/plugins/marketplace.json" <<'PY'
from pathlib import Path
import json
import sys

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    payload = json.loads(path.read_text())
    payload["plugins"] = [entry for entry in payload["plugins"] if entry["name"] == "screenote"]
    path.write_text(json.dumps(payload, indent=2) + "\n")
PY
}

capture_case="$TMP_DIR/capture-drift/repo/plugins/screenote"
make_case "$capture_case"
if ! (cd "$capture_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  (cd "$capture_case" && bash evals/lint-skills.sh) || true
  echo "FAIL: clean standalone fixture does not pass lint" >&2
  exit 1
fi
echo "PASS: clean standalone fixture passes lint"

installed_version=$(jq -r '.version' "$ROOT_DIR/.codex-plugin/plugin.json")
installed_case="$TMP_DIR/codex-cache/$installed_version"
mkdir -p "$installed_case"
cp -R "$ROOT_DIR/." "$installed_case/"
if ! (cd "$installed_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  (cd "$installed_case" && bash evals/lint-skills.sh) || true
  echo "FAIL: version-named Codex cache fixture does not pass lint" >&2
  exit 1
fi
echo "PASS: version-named Codex cache fixture passes lint"

catalog_case="$TMP_DIR/missing-codex-catalog/repo/plugins/screenote"
make_case "$catalog_case"
python3 - "$TMP_DIR/missing-codex-catalog/repo/.agents/plugins/marketplace.json" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).unlink()
PY
if (cd "$catalog_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  echo "FAIL: lint accepted a source checkout with a missing Codex catalog" >&2
  exit 1
fi
echo "PASS: lint rejects a source checkout with a missing Codex catalog"

python3 - "$capture_case/references/cli.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace("browser_screenshot_to_file", "browser_screenshot_file_missing"))
PY
if (cd "$capture_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  echo "FAIL: lint accepted missing browser_screenshot_to_file" >&2
  exit 1
fi
echo "PASS: lint rejects Browser Use capture-contract drift"

shell_case="$TMP_DIR/shell-safety/repo/plugins/screenote"
make_case "$shell_case"
python3 - "$shell_case/references/cli.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(
    path.read_text().replace(
        "--body <one-shell-quoted-explanatory-reply-argument>",
        '--body "<explanatory-reply>"',
    )
)
PY
if (cd "$shell_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  echo "FAIL: lint accepted unsafe dynamic comment interpolation" >&2
  exit 1
fi
echo "PASS: lint rejects unsafe dynamic comment interpolation"

transport_case="$TMP_DIR/screenote-http-mcp/repo/plugins/screenote"
make_case "$transport_case"
python3 - "$transport_case/.mcp.json" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["mcpServers"]["screenote"] = {
    "type": "http",
    "url": "https://screenote.invalid/mcp/messages",
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
if (cd "$transport_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  echo "FAIL: lint accepted a Screenote HTTP MCP server" >&2
  exit 1
fi
echo "PASS: lint rejects Screenote HTTP MCP transport"
