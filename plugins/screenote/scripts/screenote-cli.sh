#!/usr/bin/env bash

set +x

usage='screenote-cli.sh [--base-url URL] [--project PROJECT] <noun> <verb> [args...]'

json_error() {
  printf '%s\n' "$1" >&2
}

credential_flag_is_forbidden() {
  local argument=${1,,}

  case "$argument" in
    --*token*|--*credential*|--*api-key*|--*password*|--*secret*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

for argument in "$@"; do
  if credential_flag_is_forbidden "$argument"; then
    json_error '{"error":{"code":"credential_argument_forbidden","message":"Credential and token flags are not accepted; use Screenote environment or config authentication."}}'
    exit 64
  fi
done

if [[ ${1-} == --check-contract ]]; then
  if (($# != 1)); then
    json_error "{\"error\":{\"code\":\"invalid_arguments\",\"message\":\"Usage: $usage or screenote-cli.sh --check-contract\"}}"
    exit 64
  fi
  screenote_path=$(type -P screenote 2>/dev/null)
  if [[ -z $screenote_path ]]; then
    json_error '{"error":{"code":"screenote_not_found","message":"The Screenote CLI executable was not found on PATH.","action":"Install a compatible Screenote CLI, ensure its bin directory is on PATH, and retry."}}'
    exit 127
  fi
  contract_commands=(
    'project list'
    'page list'
    'screenshot list'
    'screenshot create'
    'annotation list'
    'annotation get'
    'comment add'
  )
  for command in "${contract_commands[@]}"; do
    read -r noun verb <<<"$command"
    if ! "$screenote_path" "$noun" "$verb" --help >/dev/null 2>&1; then
      json_error '{"error":{"code":"screenote_contract_incompatible","message":"The Screenote CLI does not expose every command required by the recorded compatibility baseline.","action":"Install or update to the pinned compatible ref and retry."}}'
      exit 65
    fi
  done
  printf '%s\n' '{"ok":true,"contract":"screenote-cli-pr-37","merge":"8d64ebb4a5d3d9f98d575da70c97750d15f7ae82"}'
  exit 0
fi

screenote_argv=()
while (($# > 0)); do
  case "$1" in
    --base-url|--project)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then
        json_error "{\"error\":{\"code\":\"invalid_arguments\",\"message\":\"Usage: $usage\"}}"
        exit 64
      fi
      screenote_argv+=("$1" "$2")
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if (($# < 2)); then
  json_error "{\"error\":{\"code\":\"invalid_arguments\",\"message\":\"Usage: $usage\"}}"
  exit 64
fi

noun=$1
verb=$2
shift 2

case "$noun $verb" in
  'project list'|\
  'page list'|\
  'screenshot list'|\
  'screenshot create'|\
  'annotation list'|\
  'annotation get'|\
  'comment add')
    ;;
  *)
    json_error '{"error":{"code":"command_not_allowed","message":"Only approved Screenote command tuples are allowed."}}'
    exit 64
    ;;
esac

for argument in "$@"; do
  case "$argument" in
    --base-url|--base-url=*|--project|--project=*)
      json_error "{\"error\":{\"code\":\"invalid_arguments\",\"message\":\"Global flags must precede the command tuple. Usage: $usage\"}}"
      exit 64
      ;;
  esac
done

screenote_path=$(type -P screenote 2>/dev/null)
if [[ -z $screenote_path ]]; then
  json_error '{"error":{"code":"screenote_not_found","message":"The Screenote CLI executable was not found on PATH.","action":"Install a compatible Screenote CLI, ensure its bin directory is on PATH, and retry."}}'
  exit 127
fi

screenote_argv+=("$noun" "$verb" "$@")
exec "$screenote_path" "${screenote_argv[@]}"
