#!/usr/bin/env bash
# Native discovery smoke tests in isolated homes and copied plugin packages.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLATFORM=${1:-all}
CONTRACT="$ROOT_DIR/plugin-surfaces.json"
CLAUDE_EXECUTABLE=${CLAUDE_EXECUTABLE:-claude}
CODEX_EXECUTABLE=${CODEX_EXECUTABLE:-codex}
PI_EXECUTABLE=${PI_EXECUTABLE:-pi}
OPENCLAW_EXECUTABLE=${OPENCLAW_EXECUTABLE:-openclaw}

case "$PLATFORM" in
  all|claude|codex|pi|openclaw) ;;
  *) printf 'usage: %s [all|claude|codex|pi|openclaw]\n' "$0" >&2; exit 64 ;;
esac

SMOKE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agent-plugin-smoke-XXXXXX")
cleanup() {
  rm -rf "$SMOKE_DIR"
}
trap cleanup EXIT

COPY_ROOT="$SMOKE_DIR/repository"
mkdir -p "$COPY_ROOT/plugins" "$COPY_ROOT/.claude-plugin" "$COPY_ROOT/.agents/plugins" "$SMOKE_DIR/homes"
cp -R "$ROOT_DIR/plugins/." "$COPY_ROOT/plugins/"
cp "$ROOT_DIR/.claude-plugin/marketplace.json" "$COPY_ROOT/.claude-plugin/marketplace.json"
cp "$ROOT_DIR/.agents/plugins/marketplace.json" "$COPY_ROOT/.agents/plugins/marketplace.json"

mapfile -t PLUGINS < <(python3 - "$CONTRACT" <<'PY'
import json
import sys

for plugin in json.load(open(sys.argv[1], encoding="utf-8"))["plugins"]:
    print(plugin["name"])
PY
)

pin_for() {
  python3 - "$CONTRACT" "$1" <<'PY'
import json
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
platform = sys.argv[2]
pins = {plugin["platforms"][platform]["tested_host_version"] for plugin in contract["plugins"]}
if len(pins) != 1 or None in pins:
    raise SystemExit(f"contract has inconsistent {platform} tested versions: {sorted(str(pin) for pin in pins)}")
print(pins.pop())
PY
}

skip_platform() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

print(json.dumps({"platform": sys.argv[1], "status": "skipped", "reason": sys.argv[2]}, sort_keys=True))
PY
  [[ ${REQUIRE_AGENT_CLI:-0} != 1 ]] || return 1
}

pass_platform() {
  python3 - "$1" "${#PLUGINS[@]}" <<'PY'
import json
import sys

print(json.dumps({"platform": sys.argv[1], "status": "passed", "plugins": int(sys.argv[2])}, sort_keys=True))
PY
}

check_version() {
  local platform=$1
  local executable=$2
  local expected actual raw
  if ! command -v "$executable" >/dev/null 2>&1; then
    if ! skip_platform "$platform" "$executable is not installed"; then
      return 1
    fi
    return 2
  fi
  expected=$(pin_for "$platform")
  raw=$("$executable" --version 2>&1 | head -1)
  case "$platform" in
    claude) actual=${raw%% *} ;;
    codex) actual=${raw##* } ;;
    pi) actual=${raw%% *} ;;
    openclaw) actual=$(awk '{print $2}' <<<"$raw") ;;
  esac
  if [[ $actual != "$expected" ]]; then
    python3 - "$platform" "$expected" "$actual" <<'PY'
import json
import sys

print(json.dumps({"platform": sys.argv[1], "status": "failed", "expectedVersion": sys.argv[2], "actualVersion": sys.argv[3]}, sort_keys=True))
PY
    return 1
  fi
}

run_claude() {
  if check_version claude "$CLAUDE_EXECUTABLE"; then
    :
  else
    local status=$?
    [[ $status == 2 ]] && return 0
    return 1
  fi
  local home="$SMOKE_DIR/homes/claude"
  local plugin marketplace
  mkdir -p "$home"
  HOME="$home" "$CLAUDE_EXECUTABLE" plugin validate --strict \
    "$COPY_ROOT/.claude-plugin/marketplace.json" >/dev/null
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" "$CLAUDE_EXECUTABLE" plugin validate --strict \
      "$COPY_ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  done
  marketplace=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$COPY_ROOT/.claude-plugin/marketplace.json")
  HOME="$home" "$CLAUDE_EXECUTABLE" plugin marketplace add "$COPY_ROOT" --scope user >/dev/null
  HOME="$home" "$CLAUDE_EXECUTABLE" plugin list --available --json >"$SMOKE_DIR/claude-available.json"
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" "$CLAUDE_EXECUTABLE" plugin install "$plugin@$marketplace" --scope user >/dev/null
  done
  HOME="$home" "$CLAUDE_EXECUTABLE" plugin list --json >"$SMOKE_DIR/claude-installed.json"
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" "$CLAUDE_EXECUTABLE" plugin details "$plugin@$marketplace" \
      >"$SMOKE_DIR/claude-details-$plugin.txt"
  done
  python3 - "$CONTRACT" "$marketplace" "$SMOKE_DIR" <<'PY'
import json
from pathlib import Path, PurePosixPath
import re
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
marketplace = sys.argv[2]
root = Path(sys.argv[3])
expected_plugins = {plugin["name"]: plugin for plugin in contract["plugins"]}
expected_ids = {f"{name}@{marketplace}" for name in expected_plugins}

available = json.load(open(root / "claude-available.json", encoding="utf-8"))
available_ids = {entry["pluginId"] for entry in available["available"]}
if available_ids != expected_ids:
    raise SystemExit(
        f"Claude marketplace inventory differs: missing={sorted(expected_ids - available_ids)}, "
        f"unexpected={sorted(available_ids - expected_ids)}"
    )

installed = json.load(open(root / "claude-installed.json", encoding="utf-8"))
installed_by_id = {entry["id"]: entry for entry in installed}
actual_ids = set(installed_by_id)
if actual_ids != expected_ids:
    raise SystemExit(
        f"Claude installed inventory differs: missing={sorted(expected_ids - actual_ids)}, "
        f"unexpected={sorted(actual_ids - expected_ids)}"
    )
for plugin_id, entry in installed_by_id.items():
    plugin = expected_plugins[plugin_id.removesuffix(f"@{marketplace}")]
    if entry.get("version") != plugin["version"] or entry.get("scope") != "user" or not entry.get("enabled"):
        raise SystemExit(f"Claude installed plugin metadata differs for {plugin_id}: {entry}")

for name, plugin in expected_plugins.items():
    details = (root / f"claude-details-{name}.txt").read_text(encoding="utf-8")
    match = re.search(r"^  Skills \(\d+\)\s+(.+)$", details, re.MULTILINE)
    if not match:
        raise SystemExit(f"Claude details did not expose a skill inventory for {name}")
    actual = {component.strip() for component in match.group(1).split(",") if component.strip()}
    expected = {
        PurePosixPath(skill["path"]).parent.name
        for skill in plugin["canonical"]["skills"]
    }
    expected.update(
        entry["name"]
        for entry in plugin["legacy_entrypoints"]
        if entry.get("platform") == "claude"
    )
    if actual != expected:
        raise SystemExit(
            f"Claude component inventory differs for {name}: missing={sorted(expected - actual)}, "
            f"unexpected={sorted(actual - expected)}"
        )
PY
  pass_platform claude
}

run_codex() {
  if check_version codex "$CODEX_EXECUTABLE"; then
    :
  else
    local status=$?
    [[ $status == 2 ]] && return 0
    return 1
  fi
  local home="$SMOKE_DIR/homes/codex-home"
  local codex_home="$SMOKE_DIR/homes/codex-state"
  local plugin marketplace
  mkdir -p "$home" "$codex_home"
  marketplace=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$COPY_ROOT/.agents/plugins/marketplace.json")
  HOME="$home" CODEX_HOME="$codex_home" "$CODEX_EXECUTABLE" plugin marketplace add "$COPY_ROOT" --json >/dev/null
  HOME="$home" CODEX_HOME="$codex_home" "$CODEX_EXECUTABLE" plugin list --available --json >"$SMOKE_DIR/codex-available.json"
  python3 - "$CONTRACT" "$SMOKE_DIR/codex-available.json" <<'PY'
import json
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
listed = json.load(open(sys.argv[2], encoding="utf-8"))
expected = {plugin["name"] for plugin in contract["plugins"]}
actual = {plugin["name"] for plugin in listed["available"]}
if actual != expected:
    raise SystemExit(
        f"Codex marketplace inventory differs: missing={sorted(expected - actual)}, "
        f"unexpected={sorted(actual - expected)}"
    )
PY
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" CODEX_HOME="$codex_home" "$CODEX_EXECUTABLE" plugin add "$plugin@$marketplace" --json >/dev/null
  done
  HOME="$home" CODEX_HOME="$codex_home" CODEX_EXECUTABLE="$CODEX_EXECUTABLE" python3 - "$CONTRACT" "$COPY_ROOT" <<'PY'
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time

contract = json.load(open(sys.argv[1], encoding="utf-8"))
expected = {
    f"{plugin['name']}:{skill['name']}"
    for plugin in contract["plugins"]
    for skill in plugin["canonical"]["skills"]
}
process = subprocess.Popen(
    [os.environ["CODEX_EXECUTABLE"], "app-server", "--stdio"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=os.environ,
)
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ)

def send(payload):
    process.stdin.write(json.dumps(payload) + "\n")
    process.stdin.flush()

def receive(identifier):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if not selector.select(timeout=0.25):
            continue
        line = process.stdout.readline()
        if not line:
            continue
        payload = json.loads(line)
        if payload.get("id") == identifier:
            return payload
    raise SystemExit(f"Codex app-server did not answer request {identifier}")

try:
    send({"method": "initialize", "id": 0, "params": {"clientInfo": {"name": "agent-plugin-smoke", "title": "Agent plugin smoke", "version": "1.0.0"}, "capabilities": {"experimentalApi": True}}})
    receive(0)
    send({"method": "initialized", "params": {}})
    send({"method": "skills/list", "id": 1, "params": {"cwds": [sys.argv[2]], "forceReload": True}})
    response = receive(1)
finally:
    process.terminate()
    process.wait(timeout=5)

entries = response["result"]["data"]
plugin_cache = Path(os.environ["CODEX_HOME"]) / "plugins" / "cache"
actual = {
    skill["name"]
    for entry in entries
    for skill in entry["skills"]
    if skill.get("scope") == "user"
    and Path(skill.get("path", "")).is_relative_to(plugin_cache)
}
if actual != expected:
    raise SystemExit(
        f"Codex native skill inventory differs: missing={sorted(expected - actual)}, "
        f"unexpected={sorted(actual - expected)}"
    )
PY
  pass_platform codex
}

run_pi() {
  if check_version pi "$PI_EXECUTABLE"; then
    :
  else
    local status=$?
    [[ $status == 2 ]] && return 0
    return 1
  fi
  local home="$SMOKE_DIR/homes/pi-home"
  local pi_home="$SMOKE_DIR/homes/pi-state"
  local plugin
  mkdir -p "$home" "$pi_home"
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" PI_CODING_AGENT_DIR="$pi_home" PI_OFFLINE=1 \
      "$PI_EXECUTABLE" install "$COPY_ROOT/plugins/$plugin" --no-approve >/dev/null
  done
  HOME="$home" PI_CODING_AGENT_DIR="$pi_home" PI_OFFLINE=1 "$PI_EXECUTABLE" list --no-approve >"$SMOKE_DIR/pi-list.txt"
  printf '%s\n' '{"type":"get_commands"}' | \
    HOME="$home" PI_CODING_AGENT_DIR="$pi_home" PI_OFFLINE=1 \
    "$PI_EXECUTABLE" --mode rpc --no-session --no-extensions --no-prompt-templates --no-themes --no-context-files --no-approve \
    >"$SMOKE_DIR/pi-commands.jsonl"
  python3 - "$CONTRACT" "$SMOKE_DIR/pi-list.txt" "$SMOKE_DIR/pi-commands.jsonl" <<'PY'
import json
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
listing = open(sys.argv[2], encoding="utf-8").read()
commands = [json.loads(line) for line in open(sys.argv[3], encoding="utf-8") if line.strip()]
expected_plugins = {plugin["name"] for plugin in contract["plugins"]}
missing_plugins = sorted(plugin for plugin in expected_plugins if plugin not in listing)
if missing_plugins:
    raise SystemExit(f"Pi package listing missed: {missing_plugins}")
expected_skills = {
    skill.get("aliases", {}).get("pi", skill["name"])
    for plugin in contract["plugins"]
    for skill in plugin["canonical"]["skills"]
}
actual = {
    command["name"].removeprefix("skill:")
    for response in commands
    for command in response.get("data", {}).get("commands", [])
    if command.get("source") == "skill"
}
if actual != expected_skills:
    raise SystemExit(
        f"Pi native skill inventory differs: missing={sorted(expected_skills - actual)}, "
        f"unexpected={sorted(actual - expected_skills)}"
    )
PY
  pass_platform pi
}

run_openclaw() {
  if check_version openclaw "$OPENCLAW_EXECUTABLE"; then
    :
  else
    local status=$?
    [[ $status == 2 ]] && return 0
    return 1
  fi
  local home="$SMOKE_DIR/homes/openclaw-home"
  local state="$SMOKE_DIR/homes/openclaw-state"
  local config="$SMOKE_DIR/homes/openclaw.json"
  local plugin
  mkdir -p "$home" "$state"
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
      "$OPENCLAW_EXECUTABLE" plugins install "$COPY_ROOT/plugins/$plugin" >/dev/null
  done
  HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
    "$OPENCLAW_EXECUTABLE" plugins inspect --all --json >"$SMOKE_DIR/openclaw-plugins.json"
  HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
    "$OPENCLAW_EXECUTABLE" skills list --eligible --json >"$SMOKE_DIR/openclaw-skills.json"
  HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
    "$OPENCLAW_EXECUTABLE" config validate --json >/dev/null
  python3 - "$CONTRACT" "$SMOKE_DIR" "$COPY_ROOT" <<'PY'
import json
from pathlib import Path
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
root = Path(sys.argv[2])
copy_root = Path(sys.argv[3])
inspection = json.load(open(root / "openclaw-plugins.json", encoding="utf-8"))
installed_root = root / "homes" / "openclaw-state" / "extensions"
plugins_by_id = {
    entry["plugin"]["id"]: entry["plugin"]
    for entry in inspection
    if Path(entry["plugin"].get("rootDir", "")).is_relative_to(installed_root)
}
expected_plugin_ids = {plugin["name"] for plugin in contract["plugins"]}
actual_plugin_ids = set(plugins_by_id)
if actual_plugin_ids != expected_plugin_ids:
    raise SystemExit(
        f"OpenClaw plugin inventory differs: missing={sorted(expected_plugin_ids - actual_plugin_ids)}, "
        f"unexpected={sorted(actual_plugin_ids - expected_plugin_ids)}"
    )
for plugin in contract["plugins"]:
    inspected = plugins_by_id.get(plugin["name"], {})
    if inspected.get("id") != plugin["name"] or inspected.get("format") != "openclaw" or inspected.get("status") != "loaded":
        raise SystemExit(f"OpenClaw did not load {plugin['name']} as a native plugin: {inspected}")
skills = json.load(open(root / "openclaw-skills.json", encoding="utf-8"))
expected = {
    skill.get("aliases", {}).get("openclaw", skill["name"])
    for plugin in contract["plugins"]
    for skill in plugin["canonical"]["skills"]
}
declared = {
    path.parent.name
    for plugin in contract["plugins"]
    for path in (copy_root / plugin["path"] / "openclaw" / "skills").glob("*/SKILL.md")
}
native = {entry["name"] for entry in skills["skills"]}
actual = native & declared
if declared != expected:
    raise SystemExit(
        f"OpenClaw package skill inventory differs: missing={sorted(expected - declared)}, "
        f"unexpected={sorted(declared - expected)}"
    )
if actual != expected:
    raise SystemExit(
        f"OpenClaw native skill inventory differs: missing={sorted(expected - actual)}, "
        f"unexpected={sorted(actual - expected)}"
    )
PY
  pass_platform openclaw
}

if [[ $PLATFORM == all || $PLATFORM == claude ]]; then run_claude; fi
if [[ $PLATFORM == all || $PLATFORM == codex ]]; then run_codex; fi
if [[ $PLATFORM == all || $PLATFORM == pi ]]; then run_pi; fi
if [[ $PLATFORM == all || $PLATFORM == openclaw ]]; then run_openclaw; fi
