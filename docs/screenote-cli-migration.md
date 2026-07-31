# Screenote CLI migration

Screenote 3.0 removes its bundled MCP/browser-adapter setup. The plugin now
uses host-native browser automation for local capture and the external
`screenote` executable for machine-readable project, screenshot, annotation,
and comment operations. There is no MCP transport or compatibility fallback.

## Compatible CLI baseline

The OAuth-first contract was merged in the reachable
[Screenote CLI PR 6](https://github.com/ivankuznetsov/screenote-cli/pull/6)
at merge `c28ac8b3b1b720ef60275e5f59db3a96f8cfa98b`. No containing release is
tagged yet, so the repository tests that exact public ref:

```bash
go install github.com/ivankuznetsov/screenote-cli/cmd/screenote@c28ac8b3b1b720ef60275e5f59db3a96f8cfa98b
plugins/screenote/scripts/screenote-cli.sh --check-contract
```

The plugin only detects and checks the executable. It never downloads it,
starts login, or opens a browser automatically. When the first containing
release is tagged, maintainers advance `screenote_cli.minimum_release` in
`plugin-surfaces.json` and regenerate; skills and tests do not carry a second
baseline.

## Authentication and project setup

Interactive setup happens outside the skill:

```bash
screenote --base-url https://screenote.ai login
```

For noninteractive use, provide `SCREENOTE_TOKEN` through the environment and
select a project without prompting:

```bash
export SCREENOTE_PROJECT=my-project
screenote project list
```

For a custom deployment, configure `SCREENOTE_BASE_URL` or trusted CLI config
outside the agent workflow. The bearer launcher rejects runtime `--base-url`
and `--config` overrides so prompt-controlled arguments cannot redirect an
authenticated request. Do not put credentials in command arguments, chat,
checked-in configuration, logs, or diagnostics. Project resolution is:

1. explicit `--project` supplied for the current request;
2. `SCREENOTE_PROJECT`;
3. the Screenote CLI config project.

An ambiguous or inaccessible project stops. Interactive agents may show
accessible choices after a `missing_project` response; noninteractive runs do
not read stdin, prompt, guess, or launch a browser.

Capture and snapshot workflows may create a project when the input explicitly
requests an exact new name:

```bash
plugins/screenote/scripts/screenote-cli.sh project create --name rabata.io
```

The command deliberately rejects global `--project`. It uses user-scoped OAuth
authorization, returns the created project object, and never runs merely
because project resolution failed. Exact accessible matches are reused instead
of duplicated.

## JSON errors

| Exit | Error | Behavior |
| ---: | --- | --- |
| `2` | `missing_token` | Stop; suggest hosted `screenote --base-url https://screenote.ai login` interactively or `SCREENOTE_TOKEN` noninteractively |
| `2` | `missing_project` | Stop; explain flag, environment, and CLI config project sources |
| `3` | Invalid/expired authentication or authorization | Stop without trying another auth mechanism |
| Any other nonzero | JSON error code from the CLI | Stop immediately and preserve the machine-readable diagnostic |

Success requires exit zero and one complete valid JSON value. Collection keys,
pagination metadata, and identifiers must match the shipped pinned workflow
contract; the plugin stops rather than inventing missing IDs.

## Capture and recovery

`screenote` captures an explicit HTTP(S) page. `snapshot` discovers and
confirms same-origin HTTP(S) routes, then performs repeated per-route captures.
Both use serial native browser automation and one approved `screenshot create`
call per private PNG; the plugin does not invoke a bulk snapshot command.

Each run creates a unique mode-`0700` directory and mode-`0600` capture files.
User-supplied local upload paths, symlinks, existing destinations, path escapes,
and non-HTTP(S) navigation are rejected. A successful upload deletes its
temporary capture unless retention was requested. A failed capture/upload
retains the unchanged private file and reports its exact recovery path; retries
use a new name.

## Feedback resolution

`feedback` lists pages, screenshots, and annotations, retrieves private crops,
applies the selected fix, and adds a comment. The approved contract does not
include the final resolution mutation, so the skill asks the user to resolve
the item in the Screenote UI after the comment succeeds.

The legacy `screenote feedback` form returns a migration message directing the
user to the standalone `feedback [viewport] [filter]` skill.
