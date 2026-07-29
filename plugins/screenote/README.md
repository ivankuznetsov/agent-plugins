# Screenote

Give your AI coding agent eyes. Capture a page or your whole app, publish it to
Screenote, annotate visually, and let Claude Code or Codex retrieve the
feedback from the terminal.

Screenote account operations use the public `screenote` CLI and OAuth. Existing
PNG/JPEG files publish directly through the CLI. A bundled, pinned Browser Use
adapter is used only when the agent needs to create new local PNG files; it
never talks to the Screenote API.

**Supports Claude Code and Codex.**

## Quick start

### 1. Install the plugin

Claude Code:

```bash
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install screenote@aikuznetsov-marketplace
```

Codex:

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open `/plugins` and install **Screenote** from **AI Kuznetsov**.

### 2. Install the Screenote CLI

```bash
go install github.com/ivankuznetsov/screenote-cli/cmd/screenote@latest
```

This requires Go 1.26 or newer and the Go bin directory on `PATH`. The skills
check the required CLI commands and offer this install when it is missing or
outdated.

### 3. Install capture prerequisites

The plugin launches a bundled adapter around
[Browser Use](https://github.com/browser-use/browser-use) `0.13.4`. Install
[uv](https://github.com/astral-sh/uv), Python 3.11+, and Chromium or Chrome.
The local `.mcp.json` pins Browser Use and MCP runtime versions and starts the
adapter on demand.

The adapter verifies exact viewport sizes, writes bounded screenshots directly
to private temporary files, and uses an ephemeral Chromium profile. It defaults
to `BROWSER_USE_HEADLESS=false`, so application login can happen safely in a
visible browser window. The profile is deleted when capture finishes.

### 4. Connect with OAuth

On a machine with a browser:

```bash
screenote --base-url https://screenote.ai login
```

For SSH, tmux, containers, and other headless sessions:

```bash
screenote --base-url https://screenote.ai login --device
```

Open the displayed authorization URL, approve the short code, and return to
the terminal. The CLI stores and refreshes OAuth credentials. The plugin never
asks you to paste a token into chat or copy one into a project.

### 5. Capture and review

```bash
/screenote http://localhost:3000/login
```

Open the returned Screenote link, draw annotations, and leave comments. Then:

```bash
/feedback
```

For a whole application:

```bash
/snapshot http://localhost:3000
```

## Architecture

```text
page ── Browser Use adapter ── local PNG files ─┐
existing PNG/JPEG files ────────────────────────┤
                                               ▼
                                    screenote snapshot (OAuth CLI)
                                               │
                                               ▼
                                  Screenote review and annotations
                                               │
                                               ▼
                              screenote annotation/comment (OAuth CLI)
```

The boundary is deliberate:

- Browser Use MCP: local navigation, sizing, scrolling, and file capture only.
- Screenote CLI: project selection, snapshot publication, annotations,
  comments, and resolution.
- No Screenote HTTP MCP server, API key, or token-based workflow is used.

## Usage

Claude Code examples use slash commands. In Codex, invoke the same shared
skills through the plugin namespace, such as `$screenote:screenote`,
`$screenote:snapshot`, and `$screenote:feedback`.

### Screenshot one page

```bash
/screenote https://myapp.com/dashboard
```

The default captures desktop (1280×800), tablet (768×1024), and mobile
(390×844) as variants of one logical screenshot. Device tabs in Screenote
switch between those variants.

Each variant is a full-page capture. The agent traverses lazy-loaded content
for at most 10 downward scrolls and caps output at 5000 px, so infinite pages
finish predictably. Captures are file-backed; the adapter does not return a
large base64 screenshot or stitch overlapping tiles.

Capture one viewport by prefixing it:

```bash
/screenote desktop https://myapp.com/dashboard
/screenote tablet  https://myapp.com/dashboard
/screenote mobile  https://myapp.com/dashboard
```

Natural-language targets also work:

```bash
/screenote the signup page
```

### Publish existing screenshots

Pass a local PNG or JPEG path when a screenshot already exists:

```bash
/screenote desktop ./tmp/dashboard.png
```

For responsive variants, pass files whose names or canonical widths identify
desktop, tablet, and mobile. The skill validates and inspects the files, copies
them into a private manifest directory, and publishes them without starting
Browser Use:

```bash
/screenote ./tmp/dashboard-desktop.png ./tmp/dashboard-mobile.png
```

File-backed conversation attachments work the same way when the host exposes a
readable local path. The skill never scans the filesystem to choose a
screenshot implicitly.

### Snapshot the entire app

```bash
/snapshot http://localhost:3000
```

The snapshot workflow discovers routes from code and the running app, confirms
the route set, handles application authentication in one ephemeral browser
session, captures serially, and publishes one resumable manifest through the
CLI. Date and Git commit metadata identify the batch.

Select one viewport when the complete route matrix would be too large:

```bash
/snapshot mobile http://localhost:3000
```

### Read and resolve feedback

```bash
/feedback
/feedback desktop
/feedback mobile login
```

The agent refreshes the project list through the CLI, selects a screenshot,
downloads private annotation crops, and can comment and resolve after making
the requested changes. Paginated versions and annotations are exhausted rather
than silently stopping at the first page.

### Project matching

The plugin validates a repo-local project cache against a fresh CLI project
list and otherwise matches the working-directory name. If no match exists, it
asks you to choose or offers to create a project through the CLI.

## Requirements

- A [Screenote](https://screenote.ai) account
- Claude Code or Codex
- The [Screenote CLI](https://github.com/ivankuznetsov/screenote-cli), installed
  with Go 1.26+
- OAuth completed with `screenote login` or `screenote login --device`
- Python 3.11+, `uv`, and Chromium/Chrome only when capturing a page with
  Browser Use; publishing existing images does not require them

## License

MIT
