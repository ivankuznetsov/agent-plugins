#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: upgrade-project.sh [--check] [--project <path>]

Upgrade the managed llm-wiki project structure in place. The default mode
applies the upgrade; --check reports drift without writing files and exits 10
when an upgrade is available.
USAGE
}

mode=apply
project=.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      mode=check
      shift
      ;;
    --project)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      project="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'llm-wiki: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

root="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$root" ] || [ ! -d "$root/.llm-wiki" ] || [ ! -d "$root/wiki" ]; then
  printf 'llm-wiki: project is not bootstrapped (expected .llm-wiki/ and wiki/)\n' >&2
  exit 1
fi

config_path="$root/.llm-wiki/config.json"
config_needs_create=0

infer_legacy_owner() {
  local file historical_commit historical_owner="" candidate_owner owners=()
  local codex_found=0 claude_found=0 pi_found=0
  local legacy_scripts=(
    "$root/.llm-wiki/refresh-wiki.sh"
    "$root/.llm-wiki/post-commit-refresh.sh"
  )

  for file in "${legacy_scripts[@]}"; do
    [ -f "$file" ] || continue
    if [ "$file" = "$root/.llm-wiki/post-commit-refresh.sh" ] && \
       grep -Fq 'case "$headless_agent" in' "$file"; then
      continue
    fi
    grep -Eq '(^|[^[:alnum:]_])codex[[:space:]]+exec([[:space:]]|$)' "$file" && codex_found=1
    grep -Eq '(^|[^[:alnum:]_])claude[[:space:]]+-p([[:space:]]|$)' "$file" && claude_found=1
    grep -Eq '(^|[^[:alnum:]_])pi[[:space:]]+(-p|--print)([[:space:]]|$)' "$file" && pi_found=1
  done

  while IFS= read -r historical_commit; do
    [ -n "$historical_commit" ] || continue
    candidate_owner="$(
      git -C "$root" show "$historical_commit:.llm-wiki/config.json" 2>/dev/null |
        sed -nE 's/.*"headless_agent"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' |
        head -n 1
    )"
    case "$candidate_owner" in
      codex|claude|pi)
        historical_owner="$candidate_owner"
        break
        ;;
    esac
  done < <(
    git -C "$root" log HEAD --diff-filter=AM --format=%H -- \
      .llm-wiki/config.json 2>/dev/null || true
  )
  if [ -n "$historical_owner" ]; then
    case "$historical_owner" in
      codex) codex_found=1 ;;
      claude) claude_found=1 ;;
      pi) pi_found=1 ;;
    esac
  else
    # A checkout may sit on a defensive branch that predates bootstrap. Fall
    # back to all reachable refs, but refuse conflicting historical owners.
    while IFS= read -r historical_commit; do
      [ -n "$historical_commit" ] || continue
      candidate_owner="$(
        git -C "$root" show "$historical_commit:.llm-wiki/config.json" 2>/dev/null |
          sed -nE 's/.*"headless_agent"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' |
          head -n 1
      )"
      case "$candidate_owner" in
        codex) codex_found=1 ;;
        claude) claude_found=1 ;;
        pi) pi_found=1 ;;
      esac
    done < <(
      git -C "$root" log --all --diff-filter=AM --format=%H -- \
        .llm-wiki/config.json 2>/dev/null || true
    )
  fi

  [ "$codex_found" -eq 0 ] || owners+=(codex)
  [ "$claude_found" -eq 0 ] || owners+=(claude)
  [ "$pi_found" -eq 0 ] || owners+=(pi)
  if [ "${#owners[@]}" -ne 1 ]; then
    if [ "${#owners[@]}" -eq 0 ]; then
      printf 'llm-wiki: cannot create .llm-wiki/config.json: no headless owner was found in legacy scripts or config history; restore the config or choose codex, claude, or pi explicitly\n' >&2
    else
      printf 'llm-wiki: cannot create .llm-wiki/config.json: multiple headless owners were found in legacy .llm-wiki scripts (%s); remove the ambiguity or create the config explicitly\n' "${owners[*]}" >&2
    fi
    return 1
  fi
  printf '%s\n' "${owners[0]}"
}

if [ -f "$config_path" ]; then
  headless_agent="$(
    sed -nE 's/.*"headless_agent"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
      "$config_path" | head -n 1
  )"
  case "$headless_agent" in
    codex|claude|pi) ;;
    *)
      printf 'llm-wiki: unsupported or missing headless_agent in .llm-wiki/config.json\n' >&2
      exit 1
      ;;
  esac
else
  headless_agent="$(infer_legacy_owner)" || exit 1
  config_needs_create=1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "$script_dir/../../.." && pwd)"
post_template="$plugin_root/templates/post-commit-refresh.sh"
compile_template="$plugin_root/templates/compile-log.sh"
for template in "$post_template" "$compile_template"; do
  if [ ! -f "$template" ]; then
    printf 'llm-wiki: bundled template missing: %s\n' "$template" >&2
    exit 1
  fi
done

hook_path="$(git -C "$root" rev-parse --path-format=absolute --git-path hooks/post-commit)"
HOOK_BEGIN='# BEGIN LLM WIKI POST-COMMIT'
HOOK_END='# END LLM WIKI POST-COMMIT'
LOG_BEGIN='<!-- BEGIN GENERATED WIKI LOG FRAGMENTS -->'
LOG_END='<!-- END GENERATED WIKI LOG FRAGMENTS -->'

managed_hook_block() {
  cat <<'HOOK'
# BEGIN LLM WIKI POST-COMMIT
if [ "${HIVE_SKIP_LLM_WIKI_POST_COMMIT:-}" != "1" ] && [ -x ".llm-wiki/post-commit-refresh.sh" ]; then
  ".llm-wiki/post-commit-refresh.sh" >/dev/null 2>&1 &
fi
# END LLM WIKI POST-COMMIT
HOOK
}

validate_hook_markers() {
  [ -f "$hook_path" ] || return 0
  local line inside=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$HOOK_BEGIN" ]; then
      if [ "$inside" -eq 1 ]; then
        printf 'llm-wiki: refusing to rewrite nested post-commit hook markers: %s\n' "$hook_path" >&2
        return 1
      fi
      inside=1
    elif [ "$line" = "$HOOK_END" ]; then
      if [ "$inside" -eq 0 ]; then
        printf 'llm-wiki: refusing to rewrite misordered post-commit hook markers: %s\n' "$hook_path" >&2
        return 1
      fi
      inside=0
    fi
  done <"$hook_path"
  if [ "$inside" -eq 1 ]; then
    printf 'llm-wiki: refusing to rewrite unmatched post-commit hook markers: %s\n' "$hook_path" >&2
    return 1
  fi
}

render_hook() {
  local output="$1" line inside=0 inserted=0
  : >"$output"
  if [ ! -f "$hook_path" ]; then
    printf '#!/usr/bin/env bash\n' >>"$output"
    managed_hook_block >>"$output"
    return
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$HOOK_BEGIN" ]; then
      if [ "$inserted" -eq 0 ]; then
        managed_hook_block >>"$output"
        inserted=1
      fi
      inside=1
      continue
    fi
    if [ "$inside" -eq 1 ]; then
      if [ "$line" = "$HOOK_END" ]; then
        inside=0
      fi
      continue
    fi
    printf '%s\n' "$line" >>"$output"
  done <"$hook_path"

  if [ "$inserted" -eq 0 ]; then
    [ ! -s "$output" ] || printf '\n' >>"$output"
    managed_hook_block >>"$output"
  fi
}

validate_hook_markers

validate_log_markers() {
  log_needs_migration=0
  [ -f "$root/wiki/log.md" ] || { log_needs_migration=1; return 0; }

  local line inside=0 begins=0 ends=0 seen=0 reason=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *"$LOG_BEGIN"* ]]; then
      seen=1
      begins=$((begins + 1))
      if [ "$line" != "$LOG_BEGIN" ] || [ "$inside" -eq 1 ] || [ "$begins" -gt 1 ]; then
        reason="nested, duplicate, or noncanonical BEGIN marker"
        break
      fi
      inside=1
    fi
    if [[ "$line" == *"$LOG_END"* ]]; then
      seen=1
      ends=$((ends + 1))
      if [ "$line" != "$LOG_END" ] || [ "$inside" -eq 0 ] || [ "$ends" -gt 1 ]; then
        reason="misordered, duplicate, or noncanonical END marker"
        break
      fi
      inside=0
    fi
  done <"$root/wiki/log.md"

  if [ -z "$reason" ] && { [ "$inside" -ne 0 ] || { [ "$seen" -eq 1 ] && { [ "$begins" -ne 1 ] || [ "$ends" -ne 1 ]; }; }; }; then
    reason="unmatched generated-log marker"
  fi
  if [ -n "$reason" ]; then
    printf 'llm-wiki: refusing to migrate malformed generated-log markers (%s): %s\n' "$reason" "$root/wiki/log.md" >&2
    return 1
  fi
  [ "$seen" -eq 1 ] || log_needs_migration=1
}

validate_log_markers
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
rendered_hook="$tmp_dir/post-commit"
render_hook "$rendered_hook"
compiled_log="$tmp_dir/log.md"

render_config() {
  cat <<JSON
{
  "headless_agent": "$headless_agent",
  "context_agents": ["claude", "codex", "pi"],
  "main_wiki_path": null,
  "created_by": "$headless_agent"
}
JSON
}

render_migrated_log() {
  local output="$1" compile_root="$tmp_dir/compile-root" legacy=""
  mkdir -p "$compile_root/wiki"
  if [ -d "$root/wiki/log.d" ]; then
    ln -s "$root/wiki/log.d" "$compile_root/wiki/log.d"
  else
    mkdir -p "$compile_root/wiki/log.d"
  fi
  bash "$compile_template" "$compile_root" --print >"$output"
  if [ -f "$root/wiki/log.md" ]; then
    legacy="$(
      LC_ALL=C awk '
        NR == 1 && $0 == "# Wiki Changelog" { in_header = 1; next }
        in_header && /^[[:space:]]*$/ { next }
        in_header && $0 == "Append-only log of all wiki operations." { in_header = 0; next }
        { in_header = 0; print }
      ' "$root/wiki/log.md" |
        LC_ALL=C awk '{ buf = (NR == 1 ? $0 : buf "\n" $0) }
          END { gsub(/^[[:space:]]+/, "", buf); gsub(/[[:space:]]+$/, "", buf); printf "%s", buf }'
    )"
  fi
  [ -z "$legacy" ] || printf '\n%s\n' "$legacy" >>"$output"
}

if [ "$config_needs_create" -eq 1 ]; then
  rendered_config="$tmp_dir/config.json"
  render_config >"$rendered_config"
fi
if [ "$log_needs_migration" -eq 1 ]; then
  render_migrated_log "$compiled_log"
fi

changes=()
if [ "$config_needs_create" -eq 1 ]; then
  changes+=(".llm-wiki/config.json (inferred owner: $headless_agent)")
fi
post_needs_upgrade=0
if [ ! -x "$root/.llm-wiki/post-commit-refresh.sh" ] || \
   ! cmp -s "$post_template" "$root/.llm-wiki/post-commit-refresh.sh"; then
  post_needs_upgrade=1
  changes+=(".llm-wiki/post-commit-refresh.sh")
fi
compile_needs_upgrade=0
if [ ! -x "$root/.llm-wiki/compile-log.sh" ] || \
   ! cmp -s "$compile_template" "$root/.llm-wiki/compile-log.sh"; then
  compile_needs_upgrade=1
  changes+=(".llm-wiki/compile-log.sh")
fi
if [ ! -d "$root/wiki/log.d" ]; then
  changes+=("wiki/log.d/")
fi
if [ "$log_needs_migration" -eq 1 ]; then
  changes+=("wiki/log.md")
fi
hook_needs_upgrade=0
if [ ! -x "$hook_path" ] || ! cmp -s "$rendered_hook" "$hook_path"; then
  hook_needs_upgrade=1
  changes+=("post-commit hook")
fi

if [ "$mode" = check ]; then
  if [ "${#changes[@]}" -eq 0 ]; then
    printf 'llm-wiki: project structure is current: %s\n' "$root"
    exit 0
  fi
  printf 'llm-wiki: upgrade available: %s\n' "$root"
  printf '  - %s\n' "${changes[@]}"
  exit 10
fi

if [ "${#changes[@]}" -eq 0 ]; then
  printf 'llm-wiki: already current: %s\n' "$root"
  exit 0
fi

mkdir -p "$root/.llm-wiki" "$root/wiki/log.d" "$(dirname "$hook_path")"
if [ "$config_needs_create" -eq 1 ]; then
  install -m 0644 "$rendered_config" "$config_path"
fi
if [ "$post_needs_upgrade" -eq 1 ]; then
  install -m 0755 "$post_template" "$root/.llm-wiki/post-commit-refresh.sh"
fi
if [ "$compile_needs_upgrade" -eq 1 ]; then
  install -m 0755 "$compile_template" "$root/.llm-wiki/compile-log.sh"
fi
if [ "$log_needs_migration" -eq 1 ]; then
  install -m 0644 "$compiled_log" "$root/wiki/log.md"
fi
if [ "$hook_needs_upgrade" -eq 1 ]; then
  existing_mode=""
  [ ! -e "$hook_path" ] || existing_mode="$(stat -c '%a' "$hook_path" 2>/dev/null || stat -f '%Lp' "$hook_path" 2>/dev/null || true)"
  install -m 0755 "$rendered_hook" "$hook_path"
  [ -z "$existing_mode" ] || chmod "$existing_mode" "$hook_path"
  chmod +x "$hook_path"
fi

printf 'llm-wiki: upgrade complete: %s\n' "$root"
printf '  - %s\n' "${changes[@]}"
