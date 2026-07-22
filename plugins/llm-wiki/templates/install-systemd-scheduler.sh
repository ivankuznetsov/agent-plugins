#!/usr/bin/env bash
set -euo pipefail

mode=apply
project=.
force_disabled=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) mode=check; shift ;;
    --disabled) force_disabled=1; shift ;;
    --project)
      [ "$#" -ge 2 ] || { printf 'Usage: %s [--check] [--disabled] [--project <path>]\n' "$0" >&2; exit 2; }
      project="$2"
      shift 2
      ;;
    *) printf 'Usage: %s [--check] [--disabled] [--project <path>]\n' "$0" >&2; exit 2 ;;
  esac
done

[ "$(uname -s 2>/dev/null || true)" = Linux ] || exit 0
root="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$root" ] || { printf 'llm-wiki: scheduler project is not a Git worktree\n' >&2; exit 1; }
primary_root="$(
  git -C "$root" worktree list --porcelain -z 2>/dev/null |
    while IFS= read -r -d '' field; do
      case "$field" in
        worktree\ *) printf '%s\n' "${field#worktree }"; break ;;
      esac
    done
)"
[ -n "$primary_root" ] || { printf 'llm-wiki: could not resolve the repository primary worktree\n' >&2; exit 1; }
common_dir="$(git -C "$primary_root" rev-parse --path-format=absolute --git-common-dir)"
shared_runner="$common_dir/llm-wiki/post-commit-refresh.sh"

user_dir="${LLM_WIKI_SYSTEMD_USER_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}"
flock_path="${LLM_WIKI_FLOCK_PATH:-$(command -v flock 2>/dev/null || true)}"
if [ -z "$flock_path" ] || [ ! -x "$flock_path" ]; then
  printf 'llm-wiki: flock is required for the bounded systemd scheduler\n' >&2
  exit 20
fi

digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print substr($1,1,8)}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print substr($1,1,8)}'
  fi
}

systemd_path() {
  printf '%s' "$1" |
    sed -e 's/\\/\\x5c/g' -e 's/ /\\x20/g' -e 's/"/\\x22/g'
}

decode_systemd_path() {
  printf '%s' "$1" |
    sed -e 's/\\x22/"/g' -e 's/\\x20/ /g' -e 's/\\x5c/\\/g'
}

systemctl_command=(systemctl)
configure_user_systemctl_command() {
  local uid runtime_dir bus_address
  uid="$(id -u)"
  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$uid}"
  bus_address="${DBUS_SESSION_BUS_ADDRESS:-}"

  systemctl_command=(systemctl)
  if [ -S "$runtime_dir/bus" ]; then
    bus_address="${bus_address:-unix:path=$runtime_dir/bus}"
    systemctl_command=(
      env "XDG_RUNTIME_DIR=$runtime_dir" "DBUS_SESSION_BUS_ADDRESS=$bus_address" systemctl
    )
  fi
}

base="$(basename "$primary_root" | sed 's/[^A-Za-z0-9_.-]/-/g')"
slug="$base-$(digest "$primary_root")"
service_name="llm-wiki-$slug.service"
timer_name="llm-wiki-$slug.timer"
service_path="$user_dir/$service_name"
timer_path="$user_dir/$timer_name"
wants_dir="$user_dir/timers.target.wants"
wants_path="$wants_dir/$timer_name"
encoded_root="$(systemd_path "$primary_root")"
encoded_runner="$(systemd_path "$shared_runner")"
encoded_flock="$(systemd_path "$flock_path")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
service_rendered="$tmp_dir/service"
timer_rendered="$tmp_dir/timer"
cat >"$service_rendered" <<UNIT
[Unit]
Description=Refresh LLM wiki for $slug
X-LLMWikiManaged=yes
ConditionFileIsExecutable=$encoded_runner

[Service]
Type=oneshot
Environment=LLM_WIKI_GLOBAL_LOCK_HELD=1
WorkingDirectory=$encoded_root
ExecStart=$encoded_flock --nonblock --conflict-exit-code 0 %t/llm-wiki-refresh.lock $encoded_runner --project $encoded_root --drain
TimeoutStartSec=45min
MemoryMax=4G
MemorySwapMax=0
UNIT
cat >"$timer_rendered" <<UNIT
[Unit]
Description=Run $service_name daily
X-LLMWikiManaged=yes

[Timer]
OnActiveSec=10min
OnUnitActiveSec=1d
RandomizedDelaySec=6h
Unit=$service_name

[Install]
WantedBy=timers.target
UNIT

obsolete=()
had_managed_unit=0
had_enabled_unit=0
shopt -s nullglob
for candidate in "$user_dir"/llm-wiki-*.service; do
  contents="$(sed -n '1,80p' "$candidate" 2>/dev/null || true)"
  configured="$(printf '%s\n' "$contents" | sed -n 's/^WorkingDirectory=//p' | head -n 1)"
  [ -n "$configured" ] || continue
  configured="$(decode_systemd_path "$configured")"
  candidate_common="$(git -C "$configured" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ "$candidate_common" = "$common_dir" ] || continue
  if ! printf '%s\n' "$contents" | grep -Fqx 'X-LLMWikiManaged=yes' && \
     ! printf '%s\n' "$contents" | grep -Eq '^Description=Refresh LLM wiki for llm-wiki-'; then
    continue
  fi
  had_managed_unit=1
  candidate_timer="${candidate%.service}.timer"
  [ -L "$wants_dir/$(basename "$candidate_timer")" ] && had_enabled_unit=1
  if [ "$candidate" != "$service_path" ]; then
    obsolete+=("$candidate" "$candidate_timer" "$wants_dir/$(basename "$candidate_timer")")
  fi
done
shopt -u nullglob

enable_timer=1
if [ "$force_disabled" -eq 1 ]; then
  enable_timer=0
elif [ "$had_managed_unit" -eq 1 ] && [ "$had_enabled_unit" -eq 0 ] && [ ! -L "$wants_path" ]; then
  enable_timer=0
fi

drift=0
[ -f "$service_path" ] && cmp -s "$service_rendered" "$service_path" || drift=1
[ -f "$timer_path" ] && cmp -s "$timer_rendered" "$timer_path" || drift=1
[ -f "$common_dir/llm-wiki/scheduler-service" ] && \
  [ "$(sed -n '1p' "$common_dir/llm-wiki/scheduler-service")" = "$service_name" ] || drift=1
[ "${#obsolete[@]}" -eq 0 ] || drift=1
if [ "$enable_timer" -eq 1 ]; then
  [ -L "$wants_path" ] && [ "$(readlink "$wants_path")" = "../$timer_name" ] || drift=1
elif [ -L "$wants_path" ]; then
  drift=1
fi

if [ "$mode" = check ]; then
  [ "$drift" -eq 0 ] && exit 0
  printf 'llm-wiki: systemd scheduler upgrade available: %s\n' "$primary_root"
  exit 10
fi
[ "$drift" -eq 1 ] || exit 0

mkdir -p "$user_dir" "$wants_dir" "$common_dir/llm-wiki"
install -m 0644 "$service_rendered" "$service_path"
install -m 0644 "$timer_rendered" "$timer_path"
printf '%s\n' "$service_name" >"$common_dir/llm-wiki/scheduler-service"
for candidate in "${obsolete[@]}"; do
  [ -e "$candidate" ] || [ -L "$candidate" ] || continue
  if [ "${LLM_WIKI_SKIP_SYSTEMCTL:-${HIVE_SKIP_LLM_WIKI_SYSTEMCTL:-}}" != 1 ] && \
     command -v systemctl >/dev/null 2>&1; then
    configure_user_systemctl_command
    case "$candidate" in
      *.service|*.timer)
        "${systemctl_command[@]}" --user stop "$(basename "$candidate")" >/dev/null 2>&1 || true
        ;;
    esac
  fi
  rm -f -- "$candidate"
done
if [ "$enable_timer" -eq 1 ]; then
  ln -sfn "../$timer_name" "$wants_path"
else
  rm -f -- "$wants_path"
fi

if [ "${LLM_WIKI_SKIP_SYSTEMCTL:-${HIVE_SKIP_LLM_WIKI_SYSTEMCTL:-}}" != 1 ] && \
   command -v systemctl >/dev/null 2>&1; then
  configure_user_systemctl_command
  "${systemctl_command[@]}" --user daemon-reload
  "${systemctl_command[@]}" --user stop "$service_name" >/dev/null 2>&1 || true
  "${systemctl_command[@]}" --user stop "$timer_name" >/dev/null 2>&1 || true
  if [ "$enable_timer" -eq 1 ]; then
    "${systemctl_command[@]}" --user start "$timer_name"
  fi
fi
printf 'llm-wiki: installed one bounded scheduler for repository: %s\n' "$primary_root"
