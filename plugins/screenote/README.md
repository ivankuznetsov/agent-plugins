# Screenote

Give an AI coding agent a visual feedback loop: capture a page or a route set,
publish new or existing PNG/JPEG images through the external Screenote JSON
CLI, retrieve visual annotations and their attachments, and comment with an
optional image after applying a fix.

The plugin ships the same `screenote`, `snapshot`, and `feedback` workflows for
Claude Code, Codex, Pi, and OpenClaw. It detects the `screenote` executable but
never installs it or starts authentication automatically.

## Install

Claude Code and Codex use the shared marketplaces:

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install screenote@aikuznetsov-marketplace
```

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
codex plugin add screenote@aikuznetsov-marketplace
```

Pi and OpenClaw install the self-contained package directory from a clone:

```bash
pi install /path/to/agent-plugins/plugins/screenote
openclaw plugins install /path/to/agent-plugins/plugins/screenote
```

## Prerequisite

Install Screenote CLI v0.4.0 or later:

```bash
go install github.com/ivankuznetsov/screenote-cli/cmd/screenote@v0.4.0
```

For an interactive machine using the hosted service, authenticate separately
from the agent workflow with:

```bash
screenote --base-url https://screenote.ai login
```

For a custom deployment, set `SCREENOTE_BASE_URL` or a trusted Screenote CLI
config before login and before invoking the plugin. The bundled bearer launcher
deliberately rejects runtime `--base-url` and `--config` overrides so untrusted
prompt content cannot redirect an authenticated request. For automation,
provide `SCREENOTE_TOKEN` through the CLI environment contract and select a
project explicitly or with `SCREENOTE_PROJECT`. Project selection uses explicit
`--project`, then `SCREENOTE_PROJECT`, then CLI config.

## Workflows

Claude Code examples use slash commands; other hosts discover the same skill
names through their native plugin surface.

Capture one page at all canonical viewports:

```text
/screenote https://example.test/login
```

Capture one viewport:

```text
/screenote mobile https://example.test/login
```

Publish an existing image without starting browser automation:

```text
/screenote desktop ./tmp/login.png
```

Multiple explicitly named files may be published together:

```text
/screenote ./tmp/login-desktop.png ./tmp/login-mobile.png
```

The helper validates file type, extension, image structure, dimensions, size,
and every source-path component for symlinks, then publishes new private copies
through one manifest. Files identified as viewport variants share one logical
version and appear behind Screenote's desktop/tablet/mobile switcher. The
workflow never passes the original path or basename in CLI file or metadata
arguments, and never deletes the source file.

Snapshot manifests require immutable commit provenance. The workflows use the
current Git commit by default and accept an explicit `git_commit=<7-40 hex>`
value for uploads invoked outside a worktree.

Discover, confirm, and capture an application route set:

```text
/snapshot https://example.test
```

Retrieve feedback, apply a fix, and add a comment:

```text
/feedback mobile login
```

The feedback workflow downloads root and reply attachments into private local
files for inspection. When the request explicitly calls for an image reply, it
can attach one approved PNG, JPEG, or WebP file. It never silently turns a
failed image reply into a text-only comment or retries an ambiguous result that
could duplicate the comment.

After the comment succeeds, resolve the item in the Screenote UI. The plugin
does not perform the final resolution mutation.

## Safety and failure behavior

- Navigation is limited to user-specified or locally discovered HTTP(S) URLs.
- Explicit PNG/JPEG paths bypass browser capture only after safe local
  validation and copying into the plugin-owned private directory.
- Native browser automation captures serially to a unique mode-`0700`
  directory with mode-`0600` files.
- `scripts/screenote-cli.sh` accepts only approved project/page/screenshot/
  annotation reads, snapshot publication, screenshot compatibility upload, and
  comment creation; endpoint/config overrides are forbidden and arguments
  remain separate argv elements.
- Credentials stay in the CLI's environment or config channels, never command
  arguments, generated files, or diagnostics.
- Exit 2 reports missing authentication/project setup, exit 3 reports rejected
  authentication, and every other nonzero result stops the flow except the
  documented read-only retry when an annotation crop is unavailable.
- Successful temporary captures are removed unless retention was requested.
  Failed captures remain private and their exact recovery path is reported.

See [the shared CLI contract](references/cli.md) for the complete allowlist,
error mapping, project precedence, capture boundary, and cleanup rules.

## Requirements

- A compatible `screenote` executable on `PATH`
- A Screenote account and an accessible project
- A Git worktree commit or an explicit `git_commit` value for manifest provenance
- A supported agent host with native browser automation only for fresh capture
  workflows; existing-image publication does not need a browser runtime

## License

MIT
