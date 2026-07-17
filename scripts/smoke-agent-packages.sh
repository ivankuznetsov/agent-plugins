#!/usr/bin/env bash
# Native discovery smoke tests in isolated homes and copied plugin packages.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLATFORM=${1:-all}
CONTRACT="$ROOT_DIR/plugin-surfaces.json"

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
    skip_platform "$platform" "$executable is not installed"
    return 2
  fi
  expected=$(pin_for "$platform")
  raw=$($executable --version 2>&1 | head -1)
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
  if check_version claude claude; then
    :
  else
    local status=$?
    [[ $status == 2 ]] && return 0
    return 1
  fi
  local plugin
  mkdir -p "$SMOKE_DIR/homes/claude"
  for plugin in "${PLUGINS[@]}"; do
    HOME="$SMOKE_DIR/homes/claude" claude plugin validate --strict \
      "$COPY_ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  done
  pass_platform claude
}

run_codex() {
  if check_version codex codex; then
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
  HOME="$home" CODEX_HOME="$codex_home" codex plugin marketplace add "$COPY_ROOT" --json >/dev/null
  HOME="$home" CODEX_HOME="$codex_home" codex plugin list --available --json >"$SMOKE_DIR/codex-available.json"
  python3 - "$CONTRACT" "$SMOKE_DIR/codex-available.json" <<'PY'
import json
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
listed = json.load(open(sys.argv[2], encoding="utf-8"))
expected = {plugin["name"] for plugin in contract["plugins"]}
actual = {plugin["name"] for plugin in listed["available"]}
missing = sorted(expected - actual)
if missing:
    raise SystemExit(f"Codex marketplace discovery missed plugins: {missing}")
PY
  for plugin in "${PLUGINS[@]}"; do
    HOME="$home" CODEX_HOME="$codex_home" codex plugin add "$plugin@$marketplace" --json >/dev/null
  done
  HOME="$home" CODEX_HOME="$codex_home" python3 - "$CONTRACT" "$COPY_ROOT" <<'PY'
import json
import os
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
    ["codex", "app-server", "--stdio"],
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
actual = {skill["name"] for entry in entries for skill in entry["skills"]}
missing = sorted(expected - actual)
if missing:
    raise SystemExit(f"Codex native skill discovery missed: {missing}")
PY
  pass_platform codex
}

run_pi() {
  if check_version pi pi; then
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
      pi install "$COPY_ROOT/plugins/$plugin" --no-approve >/dev/null
  done
  HOME="$home" PI_CODING_AGENT_DIR="$pi_home" PI_OFFLINE=1 pi list --no-approve >"$SMOKE_DIR/pi-list.txt"
  printf '%s\n' '{"type":"get_commands"}' | \
    HOME="$home" PI_CODING_AGENT_DIR="$pi_home" PI_OFFLINE=1 \
    pi --mode rpc --no-session --no-extensions --no-prompt-templates --no-themes --no-context-files --no-approve \
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
missing = sorted(expected_skills - actual)
if missing:
    raise SystemExit(f"Pi native skill discovery missed: {missing}")
PY
  pass_platform pi
}

run_openclaw() {
  if check_version openclaw openclaw; then
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
      openclaw plugins install "$COPY_ROOT/plugins/$plugin" >/dev/null
  done
  HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
    openclaw plugins inspect --all --json >"$SMOKE_DIR/openclaw-plugins.json"
  HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
    openclaw skills check --json >"$SMOKE_DIR/openclaw-skills.json"
  HOME="$home" OPENCLAW_STATE_DIR="$state" OPENCLAW_CONFIG_PATH="$config" \
    openclaw config validate --json >/dev/null
  python3 - "$CONTRACT" "$SMOKE_DIR" <<'PY'
import json
from pathlib import Path
import sys

contract = json.load(open(sys.argv[1], encoding="utf-8"))
root = Path(sys.argv[2])
inspection = json.load(open(root / "openclaw-plugins.json", encoding="utf-8"))
plugins_by_id = {entry["plugin"]["id"]: entry["plugin"] for entry in inspection}
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
actual = set(skills["eligible"])
missing = sorted(expected - actual)
if missing:
    raise SystemExit(f"OpenClaw native skill discovery missed: {missing}")
PY
  pass_platform openclaw
}

if [[ $PLATFORM == all || $PLATFORM == claude ]]; then run_claude; fi
if [[ $PLATFORM == all || $PLATFORM == codex ]]; then run_codex; fi
if [[ $PLATFORM == all || $PLATFORM == pi ]]; then run_pi; fi
if [[ $PLATFORM == all || $PLATFORM == openclaw ]]; then run_openclaw; fi
