# Screenote

Give an AI coding agent a visual feedback loop: capture a page or a route set,
publish private PNGs through the external Screenote JSON CLI, retrieve visual
annotations, and comment after applying a fix.

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

Until a tagged Screenote CLI release contains the OAuth-first command contract,
install the recorded public baseline:

```bash
go install github.com/ivankuznetsov/screenote-cli/cmd/screenote@c28ac8b3b1b720ef60275e5f59db3a96f8cfa98b
```

For an interactive machine, authenticate separately with `screenote login`.
For automation, provide `SCREENOTE_TOKEN` through the CLI environment contract
and select a project explicitly or with `SCREENOTE_PROJECT`. Project selection
uses explicit `--project`, then `SCREENOTE_PROJECT`, then CLI config.

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

Discover, confirm, and capture an application route set:

```text
/snapshot https://example.test
```

Retrieve feedback, apply a fix, and add a comment:

```text
/feedback mobile login
```

After the comment succeeds, resolve the item in the Screenote UI. The plugin
does not perform the final resolution mutation.

## Safety and failure behavior

- Navigation is limited to user-specified or locally discovered HTTP(S) URLs.
- Native browser automation captures serially to a unique mode-`0700`
  directory with mode-`0600` files.
- `scripts/screenote-cli.sh` accepts only project/page/screenshot/annotation
  reads, screenshot creation, and comment creation; arguments remain separate
  argv elements.
- Credentials stay in the CLI's environment or config channels, never command
  arguments, generated files, or diagnostics.
- Exit 2 reports missing authentication/project setup, exit 3 reports rejected
  authentication, and every other nonzero result stops the flow.
- Successful temporary captures are removed unless retention was requested.
  Failed captures remain private and their exact recovery path is reported.

See [the shared CLI contract](references/cli.md) for the complete allowlist,
error mapping, project precedence, capture boundary, cleanup rules, and the
2.x setup migration.

## Requirements

- A compatible `screenote` executable on `PATH`
- A Screenote account and an accessible project
- A supported agent host with native browser automation for capture workflows

## License

MIT
