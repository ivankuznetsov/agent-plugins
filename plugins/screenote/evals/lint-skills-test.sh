#!/usr/bin/env bash
# Mutation fixtures prove that unsafe Screenote packaging drift fails lint.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/screenote-lint-test-XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

make_case() {
  local name=$1
  local destination="$TMP_DIR/$name/screenote"
  mkdir -p "$destination"
  cp -R "$ROOT_DIR/." "$destination/"
  printf '%s\n' "$destination"
}

clean_case=$(make_case clean)
(cd "$clean_case" && bash evals/lint-skills.sh >/dev/null)
printf 'PASS: clean isolated package passes lint\n'

allowlist_case=$(make_case allowlist)
python3 - "$allowlist_case/scripts/screenote-approved-commands.sh" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
body = path.read_text()
changed = body.replace("  comment\n  add\n", "  comment\n  missing\n")
if changed == body:
    raise SystemExit("allowlist mutation did not match")
path.write_text(changed)
PY
if (cd "$allowlist_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  printf 'FAIL: lint accepted a missing approved command tuple\n' >&2
  exit 1
fi
printf 'PASS: lint rejects command allowlist drift\n'

manifest_case=$(make_case manifest)
python3 - "$manifest_case/.codex-plugin/plugin.json" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["mcpServers"] = "./retired-config.json"
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
if (cd "$manifest_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  printf 'FAIL: lint accepted retired transport metadata\n' >&2
  exit 1
fi
printf 'PASS: lint rejects retired transport metadata\n'

credential_case=$(make_case credential)
python3 - "$credential_case/skills/screenote/SKILL.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text() + "\nUnsafe example: --token a-value\n")
PY
if (cd "$credential_case" && bash evals/lint-skills.sh >/dev/null 2>&1); then
  printf 'FAIL: lint accepted a credential argument\n' >&2
  exit 1
fi
printf 'PASS: lint rejects credential arguments\n'
