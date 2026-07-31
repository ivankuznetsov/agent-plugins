#!/usr/bin/env bash

set +x

usage='screenote-cli.sh [--project PROJECT] <noun> <verb> [args...]'

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# Generated from plugin-surfaces.json. This is the single command allowlist
# shared by package validation and the bearer-safe launcher.
# shellcheck source=screenote-approved-commands.sh
source "$script_directory/screenote-approved-commands.sh"

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

endpoint_flag_is_forbidden() {
  local argument=${1,,}

  case "$argument" in
    --base-url|--base-url=*|--config|--config=*)
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
  if endpoint_flag_is_forbidden "$argument"; then
    json_error '{"error":{"code":"endpoint_argument_forbidden","message":"Endpoint and config overrides are not accepted by the bearer launcher; configure SCREENOTE_BASE_URL or trusted CLI config before invoking the agent workflow."}}'
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
  root_help=$("$screenote_path" --help 2>/dev/null) || {
    json_error '{"error":{"code":"screenote_contract_incompatible","message":"The Screenote CLI root help is unavailable.","action":"Install or update to the pinned compatible ref and retry."}}'
    exit 65
  }
  for required_global_flag in --base-url --project --config; do
    if ! grep -Fq -- "$required_global_flag" <<<"$root_help"; then
      json_error '{"error":{"code":"screenote_contract_incompatible","message":"The Screenote CLI does not expose every command required by the recorded compatibility baseline.","action":"Install or update to the pinned compatible ref and retry."}}'
      exit 65
    fi
  done

  for ((command_index = 0; command_index < ${#SCREENOTE_APPROVED_COMMANDS[@]}; command_index += 2)); do
    noun=${SCREENOTE_APPROVED_COMMANDS[command_index]}
    verb=${SCREENOTE_APPROVED_COMMANDS[command_index + 1]}
    command_help=$("$screenote_path" "$noun" "$verb" --help 2>/dev/null) || {
      json_error '{"error":{"code":"screenote_contract_incompatible","message":"The Screenote CLI does not expose every command required by the recorded compatibility baseline.","action":"Install or update to the pinned compatible ref and retry."}}'
      exit 65
    }
    required_flags=()
    case "$noun $verb" in
      'project create') required_flags=(--name) ;;
      'screenshot list') required_flags=(--page --status --limit --offset) ;;
      'screenshot create') required_flags=(--title --page --file) ;;
      'annotation list') required_flags=(--screenshot --status --viewport --limit --offset) ;;
      'annotation get') required_flags=(--annotation --crop-file) ;;
      'comment add') required_flags=(--annotation --body) ;;
    esac
    for required_flag in "${required_flags[@]}"; do
      if ! grep -Fq -- "$required_flag" <<<"$command_help"; then
        json_error '{"error":{"code":"screenote_contract_incompatible","message":"The Screenote CLI command flags do not match the recorded compatibility baseline.","action":"Install or update to the pinned compatible ref and retry."}}'
        exit 65
      fi
    done
  done
  printf '%s\n' '{"ok":true,"contract":"screenote-cli-pr-6","merge":"c28ac8b3b1b720ef60275e5f59db3a96f8cfa98b"}'
  exit 0
fi

screenote_argv=()
project_was_supplied=false
while (($# > 0)); do
  case "$1" in
    --project)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then
        json_error "{\"error\":{\"code\":\"invalid_arguments\",\"message\":\"Usage: $usage\"}}"
        exit 64
      fi
      screenote_argv+=("$1" "$2")
      project_was_supplied=true
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

if ! screenote_command_is_approved "$noun" "$verb"; then
  json_error '{"error":{"code":"command_not_allowed","message":"Only approved Screenote command tuples are allowed."}}'
  exit 64
fi

if [[ $noun == project && $verb == create ]]; then
  if [[ $project_was_supplied == true ]] || (($# != 2)) ||
    [[ $1 != --name || -z ${2//[[:space:]]/} || $2 == -* ]]; then
    json_error '{"error":{"code":"invalid_arguments","message":"Project creation requires exactly: project create --name NAME, without a global --project."}}'
    exit 64
  fi
fi

for argument in "$@"; do
  case "$argument" in
    --project|--project=*)
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
