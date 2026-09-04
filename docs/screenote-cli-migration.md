# Screenote CLI migration

Screenote 3.0 removes its bundled MCP/browser-adapter setup. The plugin now
uses host-native browser automation for local capture and the external
`screenote` executable for machine-readable project, screenshot, annotation,
and comment operations. There is no MCP transport or compatibility fallback.

## Compatible CLI baseline

The current contract is released as
[Screenote CLI v0.4.1](https://github.com/ivankuznetsov/screenote-cli/releases/tag/v0.4.1).
It was merged by [PR 18](https://github.com/ivankuznetsov/screenote-cli/pull/18)
at `cce90049d1335413bd903d7da4882d20615fa5d3`. The repository tests that exact
public ref:

```bash
go install github.com/ivankuznetsov/screenote-cli/cmd/screenote@v0.4.1
plugins/screenote/scripts/screenote-cli.sh --check-contract
```

The plugin only detects and checks the executable. It never downloads it,
starts login, or opens a browser automatically. Maintainers advance the four
`screenote_cli` provenance fields in `plugin-surfaces.json` together and
regenerate; skills and tests do not carry a second baseline.

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

Success requires exit zero and one complete valid JSON value for ordinary
commands. Snapshot publication emits JSON Lines and additionally requires a
final `snapshot_ready` event with `review_url`. Collection keys, pagination
metadata, and identifiers must match the shipped pinned workflow contract; the
plugin stops rather than inventing missing IDs.

## Capture and recovery

`screenote` captures an explicit HTTP(S) page. `snapshot` discovers and
confirms same-origin HTTP(S) routes, then performs repeated per-route captures.
Both use serial native browser automation, build one complete manifest, and
invoke `snapshot --manifest` once so viewport variants share one logical
version.

Each run creates a unique mode-`0700` directory and mode-`0600` capture files.
User-supplied local upload paths, symlinks, existing destinations, path escapes,
and non-HTTP(S) navigation are rejected. A successful upload deletes its
temporary captures and manifest unless retention was requested. A failed
capture/upload retains the unchanged private directory and reports its exact
recovery path; an unchanged manifest retry resumes the same Snapshot.

## Feedback resolution

`feedback` lists pages, screenshots, and annotations, then retrieves private
crops plus root and reply attachments. It applies the selected fix and adds a
comment, optionally with one explicitly requested image. An ambiguous image
comment is not retried because it may already exist; an unsupported image
comment never falls back to text-only creation. The approved contract does not
include the final resolution mutation, so the skill asks the user to resolve
the item in the Screenote UI after the comment succeeds.

The legacy `screenote feedback` form returns a migration message directing the
user to the standalone `feedback [viewport] [filter]` skill.
