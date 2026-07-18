#!/usr/bin/env bash
set -euo pipefail

# Transactional LLM-wiki post-commit refresh.
#
# Every relevant commit is queued in the shared Git directory. One worker
# drains that queue into a dedicated llm-wiki/refresh branch checked out in a
# disposable managed worktree. User checkouts are read-only inputs: neither the
# committing checkout nor the primary checkout is used as an agent workspace,
# staging area, log destination, or QMD cache.

committing_tree="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$committing_tree"

retry_selector=""
case "$#" in
  0) ;;
  2)
    if [ "$1" != "--retry-failed" ]; then
      printf 'Usage: %s [--retry-failed <sha|all>]\n' "$0" >&2
      exit 2
    fi
    retry_selector="$2"
    if [ "$retry_selector" != all ] && \
       [[ ! "$retry_selector" =~ ^[0-9a-fA-F]{40,64}$ ]]; then
      printf 'llm-wiki: retry selector must be a full source SHA or all\n' >&2
      exit 2
    fi
    ;;
  *)
    printf 'Usage: %s [--retry-failed <sha|all>]\n' "$0" >&2
    exit 2
    ;;
esac

configure_git_tool_environment() {
  GIT_ENV_UNSET_ARGS=()
  GIT_ENV_NAMES=()
  local name
  while IFS= read -r name; do
    if [ -n "$name" ]; then
      GIT_ENV_UNSET_ARGS+=("-u" "$name")
      GIT_ENV_NAMES+=("$name")
    fi
  done < <(git rev-parse --local-env-vars 2>/dev/null || true)
}

run_without_git_env() {
  env "${GIT_ENV_UNSET_ARGS[@]+"${GIT_ENV_UNSET_ARGS[@]}"}" "$@"
}

run_with_timeout() {
  local seconds="$1"
  local timeout_bin
  shift

  timeout_bin="$(command -v timeout 2>/dev/null || true)"
  if [ -z "$timeout_bin" ] || [ ! -x "$timeout_bin" ]; then
    timeout_bin="$(command -v gtimeout 2>/dev/null || true)"
  fi
  if [ -z "$timeout_bin" ] || [ ! -x "$timeout_bin" ]; then
    printf 'llm-wiki: bounded execution unavailable (install timeout or gtimeout)\n' >&2
    return 125
  fi

  run_without_git_env "$timeout_bin" "$seconds" "$@"
}

clear_git_tool_environment() {
  local name
  for name in "${GIT_ENV_NAMES[@]}"; do
    unset "$name"
  done
}

configure_git_tool_environment

common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[ -n "$common_dir" ] || exit 0
state_dir="$common_dir/llm-wiki"
pending_dir="$state_dir/pending"
failed_dir="$state_dir/failed"
failure_count_file="$state_dir/consecutive-failures"
breaker_file="$state_dir/refresh-disabled"
lock_ref="${LLM_WIKI_LOCK_REF:-refs/llm-wiki/refresh-lock}"
refresh_root="$state_dir/refresh-worktree"
log_file="$state_dir/post-commit-refresh.log"
refresh_branch="${LLM_WIKI_REFRESH_BRANCH:-llm-wiki/refresh}"
lock_owner_oid=""
mkdir -p "$pending_dir" "$failed_dir"

log_line() {
  printf '[llm-wiki][%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$log_file" 2>/dev/null || true
}

configure_qmd_environment() {
  local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  if ! mkdir -p "$cache_home/qmd" 2>/dev/null || ! touch "$cache_home/qmd/.write-test" 2>/dev/null; then
    export XDG_CACHE_HOME="$state_dir/cache"
    mkdir -p "$XDG_CACHE_HOME/qmd"
    export LLM_WIKI_QMD_CACHE_DIR="$XDG_CACHE_HOME/qmd"
  else
    rm -f "$cache_home/qmd/.write-test"
    export LLM_WIKI_QMD_CACHE_DIR="$cache_home/qmd"
  fi
}

run_qmd() {
  command -v qmd >/dev/null 2>&1 || return 0
  run_with_timeout "${LLM_WIKI_QMD_TIMEOUT:-900}" qmd "$@"
}

sha="$(git rev-parse HEAD 2>/dev/null || true)"
[ -n "$sha" ] || exit 0
if [ -z "$retry_selector" ]; then
  changed_files="$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true)"
  [ -n "$changed_files" ] || exit 0

  if ! printf '%s\n' "$changed_files" | grep -Eq \
    '(^|/)(schema\.rb|structure\.sql|db/migrate/|migrations/|models/|entities/|prisma/schema\.prisma|routes|controllers|handlers|resolvers|app/|src/|lib/|test/|tests/|spec/|templates/|config/|bin/|README\.md|Gemfile|Gemfile\.lock|package\.json|package-lock\.json|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock|requirements\.txt|pyproject\.toml|poetry\.lock|composer\.json|composer\.lock|docs/|wiki/|raw/notes/|plans/|todos/|CHANGELOG\.md|AGENTS\.md|CLAUDE\.md)'; then
    exit 0
  fi

  if [ -f "$failed_dir/$sha" ]; then
    log_line "source $sha remains quarantined; skipping automatic refresh"
    exit 0
  fi
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
  queue_tmp="$pending_dir/.${sha}.$$"
  {
    printf '%s\t%s\n' "$sha" "$branch"
    printf '%s\n' "$changed_files"
  } >"$queue_tmp"
  mv -f "$queue_tmp" "$pending_dir/$sha"

  if [ -f "$breaker_file" ]; then
    log_line "automatic refresh disabled after consecutive failures; source $sha queued"
    exit 0
  fi
fi

# From this point onward every Git command is nested maintenance work against
# the managed refresh worktree, not inspection of the triggering hook context.
clear_git_tool_environment

process_identity() {
  local pid="$1"
  if [ -r "/proc/$pid/stat" ]; then
    awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true
  else
    ps -o lstart= -p "$pid" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
  fi
}

lock_owner_stale() {
  local owner_oid="$1" owner pid identity current_identity
  owner="$(git cat-file -p "$owner_oid" 2>/dev/null || true)"
  IFS='|' read -r pid _ identity _ <<<"$owner"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    current_identity="$(process_identity "$pid")"
    if [ -z "$identity" ] || [ -z "$current_identity" ] || [ "$identity" = "$current_identity" ]; then
      return 1
    fi
  fi
  return 0
}

acquire_lock() {
  local wait_seconds deadline now owner current_oid expected_oid zero_oid
  wait_seconds="${LLM_WIKI_LOCK_WAIT_SECONDS:-60}"
  now="$(date +%s 2>/dev/null || echo 0)"
  deadline="$((now + wait_seconds))"
  owner="$$|$now|$(process_identity "$$")|${RANDOM:-0}"
  lock_owner_oid="$(printf '%s\n' "$owner" | git hash-object -w --stdin)"
  zero_oid="${lock_owner_oid//?/0}"

  while true; do
    current_oid="$(git rev-parse --verify --quiet "$lock_ref" 2>/dev/null || true)"
    if [ -z "$current_oid" ] || lock_owner_stale "$current_oid"; then
      expected_oid="${current_oid:-$zero_oid}"
      if git update-ref "$lock_ref" "$lock_owner_oid" "$expected_oid" 2>/dev/null; then
        [ -n "$current_oid" ] && log_line "reclaimed stale refresh lock"
        return 0
      fi
      continue
    fi

    now="$(date +%s 2>/dev/null || echo 0)"
    [ "$now" -ge "$deadline" ] && return 1
    sleep 1
  done
}

restore_failed_sources() {
  local file restored=0 has_pending=0
  if [ "$retry_selector" = all ]; then
    shopt -s nullglob
    for file in "$failed_dir"/*; do
      [ -f "$file" ] || continue
      if ! mv -f -- "$file" "$pending_dir/$(basename "$file")"; then
        shopt -u nullglob
        printf 'llm-wiki: could not restore quarantined source %s\n' "$(basename "$file")" >&2
        return 1
      fi
      restored=$((restored + 1))
    done
    shopt -u nullglob
  elif [ -f "$failed_dir/$retry_selector" ]; then
    if ! mv -f -- "$failed_dir/$retry_selector" "$pending_dir/$retry_selector"; then
      printf 'llm-wiki: could not restore quarantined source %s\n' "$retry_selector" >&2
      return 1
    fi
    restored=1
  elif [ -f "$pending_dir/$retry_selector" ]; then
    restored=0
  else
    printf 'llm-wiki: no quarantined source %s\n' "$retry_selector" >&2
    return 1
  fi

  shopt -s nullglob
  for file in "$pending_dir"/*; do
    if [ -f "$file" ]; then
      has_pending=1
      break
    fi
  done
  shopt -u nullglob
  if [ "$restored" -eq 0 ] && [ "$has_pending" -eq 0 ]; then
    printf 'llm-wiki: no quarantined or pending sources to retry\n'
    return 1
  fi
  printf 'llm-wiki: retrying %s restored source(s) with queued work\n' "$restored"
}

failed_sources_present() {
  local file
  shopt -s nullglob
  for file in "$failed_dir"/*; do
    if [ -f "$file" ]; then
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

if ! acquire_lock; then
  log_line "refresh remains queued; worker lock was busy"
  if [ -n "$retry_selector" ]; then
    printf 'llm-wiki: retry deferred; refresh worker lock is busy\n' >&2
    exit 1
  fi
  exit 0
fi

cleanup_refresh_worktree() {
  if git worktree list --porcelain 2>/dev/null | grep -Fqx "worktree $refresh_root"; then
    git worktree remove --force "$refresh_root" >>"$log_file" 2>&1 || true
  elif [ -e "$refresh_root" ]; then
    rm -rf "$refresh_root" 2>/dev/null || true
  fi
}

# Invoked indirectly by the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  cleanup_refresh_worktree
  [ -n "$lock_owner_oid" ] && git update-ref -d "$lock_ref" "$lock_owner_oid" 2>/dev/null || true
}
trap cleanup EXIT

default_base_ref() {
  local candidate
  candidate="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || true)"
  for candidate in "$candidate" refs/remotes/origin/main refs/remotes/origin/master refs/heads/main refs/heads/master; do
    [ -n "$candidate" ] || continue
    if git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$sha"
}

prepare_refresh_worktree() {
  local base_ref
  base_ref="$(default_base_ref)"
  cleanup_refresh_worktree
  mkdir -p "$state_dir"

  if git show-ref --verify --quiet "refs/heads/$refresh_branch"; then
    git worktree add "$refresh_root" "$refresh_branch" >>"$log_file" 2>&1 || return 1
    if ! HIVE_SKIP_LLM_WIKI_POST_COMMIT=1 \
         git -C "$refresh_root" -c core.hooksPath=/dev/null rebase "$base_ref" >>"$log_file" 2>&1; then
      HIVE_SKIP_LLM_WIKI_POST_COMMIT=1 \
        git -C "$refresh_root" -c core.hooksPath=/dev/null rebase --abort >>"$log_file" 2>&1 || true
      log_line "ERROR: could not rebase $refresh_branch onto $base_ref; queue retained"
      return 1
    fi
  else
    git worktree add -b "$refresh_branch" "$refresh_root" "$base_ref" >>"$log_file" 2>&1 || return 1
  fi
}

seed_untracked_local_wiki() {
  if [ -n "$(git -C "$refresh_root" ls-files -- wiki)" ] || \
     [ ! -e "$committing_tree/wiki" ]; then
    return 0
  fi
  if [ -L "$committing_tree/wiki" ] || [ ! -d "$committing_tree/wiki" ]; then
    log_line "ERROR: refusing to seed a non-directory or symlinked local wiki; queue retained"
    return 1
  fi

  mkdir -p "$refresh_root/wiki"
  cp -Rp "$committing_tree/wiki/." "$refresh_root/wiki/" >>"$log_file" 2>&1 || {
    log_line "ERROR: could not seed untracked local wiki; queue retained"
    return 1
  }
  log_line "seeded refresh branch from untracked local wiki snapshot"
}

wiki_only_changes() {
  local path
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    case "$path" in
      wiki/*) ;;
      *) log_line "ERROR: refresh attempted non-wiki change: $path"; return 1 ;;
    esac
  done < <(
    {
      git -C "$refresh_root" diff --name-only
      git -C "$refresh_root" diff --cached --name-only
      git -C "$refresh_root" ls-files --others --exclude-standard --directory
      git -C "$refresh_root" ls-files --others --ignored --exclude-standard --directory
    } | sort -u
  )
}

run_refresh_agent() {
  local prompt="$1"
  if [ -n "${LLM_WIKI_REFRESH_CMD:-}" ]; then
    run_with_timeout "${LLM_WIKI_REFRESH_TIMEOUT:-1800}" \
      "$LLM_WIKI_REFRESH_CMD" "$refresh_root" "$prompt" >>"$log_file" 2>&1
    return $?
  fi

  local headless_agent timeout_seconds
  headless_agent="$(
    sed -nE 's/.*"headless_agent"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
      "$committing_tree/.llm-wiki/config.json" | head -n 1
  )"
  case "$headless_agent" in
    codex)
      local add_dir_args=( --add-dir "$LLM_WIKI_QMD_CACHE_DIR" )
      run_with_timeout "${LLM_WIKI_CODEX_TIMEOUT:-1800}" \
        codex exec "${add_dir_args[@]}" -C "$refresh_root" "$prompt" >>"$log_file" 2>&1
      ;;
    claude)
      timeout_seconds="${LLM_WIKI_CLAUDE_TIMEOUT:-1800}"
      (cd "$refresh_root" && run_with_timeout "$timeout_seconds" \
        claude -p "$prompt" --allowedTools "Bash,Read,Edit,Write" \
        --add-dir "$refresh_root" --max-budget-usd 0.50) >>"$log_file" 2>&1
      ;;
    pi)
      timeout_seconds="${LLM_WIKI_PI_TIMEOUT:-1800}"
      (cd "$refresh_root" && run_with_timeout "$timeout_seconds" \
        pi -p --no-session --tools read,bash,edit,write,grep,find,ls \
        "$prompt") >>"$log_file" 2>&1
      ;;
    *)
      log_line "ERROR: unsupported or missing headless_agent in .llm-wiki/config.json"
      return 1
      ;;
  esac
}

snapshot_queue() {
  QUEUE_FILES=()
  local path
  shopt -s nullglob
  for path in "$pending_dir"/*; do
    [ -f "$path" ] && QUEUE_FILES+=("$path")
  done
  shopt -u nullglob
  [ "${#QUEUE_FILES[@]}" -gt 0 ]
}

source_receipted() {
  local queued_sha="$1"
  git show-ref --verify --quiet "refs/llm-wiki/receipts/$queued_sha" && return 0
  git -C "$refresh_root" log --format=%B 2>/dev/null | \
    grep -Fqx "LLM-Wiki-Source: $queued_sha"
}

write_source_receipts() {
  local refresh_head file queued_sha queued_branch
  refresh_head="$(git -C "$refresh_root" rev-parse HEAD)"
  {
    printf 'start\n'
    for file in "${QUEUE_FILES[@]}"; do
      IFS=$'\t' read -r queued_sha queued_branch <"$file"
      printf 'update refs/llm-wiki/receipts/%s %s\n' "$queued_sha" "$refresh_head"
    done
    printf 'commit\n'
  } | git update-ref --stdin >>"$log_file" 2>&1
}

prune_receipted_queue_files() {
  local file queued_sha queued_branch
  local retained=()
  for file in "${QUEUE_FILES[@]}"; do
    IFS=$'\t' read -r queued_sha queued_branch <"$file"
    if source_receipted "$queued_sha"; then
      rm -f -- "$file"
      log_line "acknowledged previously committed source $queued_sha"
    else
      retained+=("$file")
    fi
  done
  QUEUE_FILES=("${retained[@]}")
}

record_batch_failure() {
  local file queued_sha queued_branch count max_attempts count_tmp remaining=0
  max_attempts="${LLM_WIKI_MAX_REFRESH_ATTEMPTS:-2}"
  [[ "$max_attempts" =~ ^[1-9][0-9]*$ ]] || max_attempts=2

  for file in "${QUEUE_FILES[@]}"; do
    [ -f "$file" ] || continue
    IFS=$'\t' read -r queued_sha queued_branch <"$file"
    if source_receipted "$queued_sha"; then
      rm -f -- "$file"
      log_line "acknowledged committed source $queued_sha after receipt write failure"
      continue
    fi
    remaining=1
  done
  if [ "$remaining" -eq 0 ]; then
    rm -f -- "$failure_count_file" "$breaker_file"
    return 0
  fi

  count="$(sed -n '1p' "$failure_count_file" 2>/dev/null || true)"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  count="$((count + 1))"
  count_tmp="$state_dir/.consecutive-failures.$$"
  printf '%s\n' "$count" >"$count_tmp"
  mv -f "$count_tmp" "$failure_count_file"

  if [ "$count" -ge "$max_attempts" ]; then
    for file in "${QUEUE_FILES[@]}"; do
      [ -f "$file" ] || continue
      IFS=$'\t' read -r queued_sha queued_branch <"$file"
      mv -f -- "$file" "$failed_dir/$queued_sha"
    done
    printf '%s\n' "$count" >"$breaker_file"
    log_line "ERROR: automatic refresh disabled after $count consecutive failed batch(es); run .llm-wiki/post-commit-refresh.sh --retry-failed all"
  else
    log_line "refresh batch failed ($count/$max_attempts consecutive failures); queue retained"
  fi
}

process_queue_batch() {
  local sources="" file queued_sha queued_branch paths prompt short_source
  local commit_args=()
  prune_receipted_queue_files
  if [ "${#QUEUE_FILES[@]}" -eq 0 ]; then
    rm -f -- "$failure_count_file"
    if ! failed_sources_present; then
      rm -f -- "$breaker_file"
    fi
    return 0
  fi
  for file in "${QUEUE_FILES[@]}"; do
    IFS=$'\t' read -r queued_sha queued_branch <"$file"
    commit_args+=( -m "LLM-Wiki-Source: $queued_sha" )
    paths="$(sed -n '2,$p' "$file")"
    sources+="- commit ${queued_sha} on branch ${queued_branch}; changed paths:\n"
    while IFS= read -r path; do
      [ -n "$path" ] && sources+="  - ${path}\n"
    done <<<"$paths"
  done

  prompt="$(cat <<PROMPT
Refresh this project's LLM wiki for the queued committed changes below.

You are running in the dedicated managed wiki-refresh worktree at ${refresh_root}.
This worktree is based on the current default branch. Inspect each source commit
with 'git show <sha>' and 'git show <sha>:<path>'; a source commit may belong to
another branch and need not be checked out here.

Queued sources:
$(printf '%b' "$sources")

Read .llm-wiki/config.json, AGENTS.md, CLAUDE.md, wiki/index.md, wiki/gaps.md,
and recent wiki/log.md entries first. Search main_wiki_path when configured.
Update only files under wiki/. Update affected architecture, command/API,
dependency, data-model, planning, or documentation pages as warranted by the
actual diffs. Update wiki/index.md only when coverage changes. Add one
wiki/log.d/<timestamp>-<slug>.md fragment for this coalesced batch without
editing compiled wiki/log.md. Record uncertainty in wiki/gaps.md. Do not run
qmd; the wrapper handles bounded index maintenance. Do not invent facts.
PROMPT
)"

  if ! run_refresh_agent "$prompt"; then
    log_line "ERROR: refresh agent failed; generated work discarded and queue retained"
    return 1
  fi
  wiki_only_changes || return 1

  if [ -x "$refresh_root/.llm-wiki/compile-log.sh" ]; then
    bash "$refresh_root/.llm-wiki/compile-log.sh" "$refresh_root" >>"$log_file" 2>&1 || {
      log_line "ERROR: changelog compilation failed; queue retained"
      return 1
    }
  else
    log_line "WARN: compile-log.sh missing; leaving wiki/log.md unchanged"
  fi
  wiki_only_changes || return 1

  if [ -e "$refresh_root/wiki" ] || [ -n "$(git -C "$refresh_root" ls-files -- wiki)" ]; then
    git -C "$refresh_root" add -f -A -- wiki >>"$log_file" 2>&1 || return 1
  fi
  wiki_only_changes || return 1
  if ! git -C "$refresh_root" diff --cached --quiet; then
    short_source="$(basename "${QUEUE_FILES[0]}")"
    if ! HIVE_SKIP_LLM_WIKI_POST_COMMIT=1 \
         git -C "$refresh_root" -c core.hooksPath=/dev/null \
         commit --only -m "docs(wiki): queued refresh for ${#QUEUE_FILES[@]} commit(s) at ${short_source:0:12}" \
         "${commit_args[@]}" \
         -- wiki >>"$log_file" 2>&1; then
      log_line "ERROR: refresh commit failed; queue retained"
      return 1
    fi
  fi

  if ! write_source_receipts; then
    log_line "ERROR: could not write source receipts; queue retained"
    return 1
  fi
  rm -f -- "${QUEUE_FILES[@]}"
  rm -f -- "$failure_count_file"
  if failed_sources_present; then
    log_line "refresh succeeded, but quarantined sources remain; automatic refresh stays disabled"
  else
    rm -f -- "$breaker_file"
  fi
  ( cd "$refresh_root" && run_qmd update ) >>"$log_file" 2>&1 || true
  ( cd "$refresh_root" && run_qmd embed --max-docs-per-batch 64 --max-batch-mb 64 ) >>"$log_file" 2>&1 || true
  return 0
}

configure_qmd_environment
if [ -n "$retry_selector" ]; then
  if ! restore_failed_sources; then
    exit 1
  fi
# A worker can pass the pre-lock check and then wait while its predecessor opens
# the circuit. Re-check under the lock before any worktree or provider action.
elif [ -f "$breaker_file" ]; then
  log_line "automatic refresh circuit remains open; queued sources retained"
  exit 0
fi
if ! prepare_refresh_worktree; then
  log_line "ERROR: could not prepare managed refresh worktree; queue retained"
  if [ -n "$retry_selector" ]; then
    printf 'llm-wiki: retry failed while preparing the refresh worktree\n' >&2
    exit 1
  fi
  exit 0
fi
if ! seed_untracked_local_wiki; then
  if [ -n "$retry_selector" ]; then
    printf 'llm-wiki: retry failed while seeding the local wiki snapshot\n' >&2
    exit 1
  fi
  exit 0
fi

while snapshot_queue; do
  if ! process_queue_batch; then
    record_batch_failure
    if [ -n "$retry_selector" ]; then
      printf 'llm-wiki: retry failed; see %s\n' "$log_file" >&2
      exit 1
    fi
    exit 0
  fi
done

if [ -n "$retry_selector" ]; then
  if [ -f "$breaker_file" ]; then
    printf 'llm-wiki: selected refresh completed; quarantined sources remain, so the circuit stays open\n'
  else
    printf 'llm-wiki: queued refresh completed successfully\n'
  fi
fi

main_checkout="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
project_name="$(basename "${main_checkout:-$committing_tree}")"
for sync_dir in "$HOME/wikis/.sync-needed" "$(dirname "${main_checkout:-$committing_tree}")/wikis/.sync-needed"; do
  if [ -d "$(dirname "$sync_dir")" ]; then
    mkdir -p "$sync_dir"
    touch "$sync_dir/$project_name"
  fi
done

exit 0
