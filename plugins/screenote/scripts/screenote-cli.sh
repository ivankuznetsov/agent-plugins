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
