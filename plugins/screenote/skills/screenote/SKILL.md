---
name: screenote
description: Capture a page at desktop/tablet/mobile viewports and publish it with the Screenote CLI for human annotation
metadata:
  argument: "[desktop|tablet|mobile] [url-or-description]"
---

# Screenote — Visual Feedback Loop

Capture one page with the bundled Browser Use adapter, publish the selected
viewport files as one logical screenshot through the OAuth CLI, and return its
review URL.

Read and follow [`../../references/cli.md`](../../references/cli.md) completely
before running this workflow. Its CLI/OAuth, project cache, Browser Use
preflight, untrusted-page boundary, exact full-page algorithm, manifest,
cleanup, and error rules are mandatory. Browser Use is capture-only; every
Screenote operation uses the CLI.

## Parse the request

- An initial `desktop`, `tablet`, or `mobile` selects only that viewport.
- Otherwise capture desktop, tablet, and mobile.
- If the argument starts with `feedback`, direct the user to the `feedback`
  skill and stop.
- Treat the remainder as a URL, path, or page description.

Canonical dimensions:

| Viewport | Width | Height |
| --- | ---: | ---: |
| desktop | 1280 | 800 |
| tablet | 768 | 1024 |
| mobile | 390 | 844 |

## 1. Establish the CLI data plane

Run the shared CLI capability, OAuth, fresh project-list, and repo-local cache
procedure. Do not start browser work until it succeeds. Never use a Screenote
MCP server, direct HTTP request, or upload URL as a fallback.

## 2. Resolve the page

- Use a complete `http://` or `https://` URL unchanged.
- Resolve a relative path against the running development server. Detect the
  real server and port from processes and project configuration; do not assume
  port 3000 without evidence.
- Resolve a natural-language description from application routes.
- For application login, prefer the visible ephemeral browser window or
  environment-provided test credentials. Never request production credentials
  in chat.

## 3. Preflight and capture

Create the private invocation directory from the shared contract. Before
navigation, require `browser_navigate`, `browser_set_viewport`,
`browser_page_metrics`, `browser_scroll_to`,
`browser_screenshot_to_file`, and `browser_close_all`, then run the shared exact
viewport preflight for every requested dimension.

Capture each selected viewport serially with the shared exact full-page
procedure. Navigate afresh after sizing, settle with numeric metrics only,
traverse lazy-loaded content within the 5000 px/10-scroll limits, verify exact
scroll-to-top, and write `<viewport>.png` under the private directory. Record
exactly one terminal row per viewport in `capture-status.jsonl`.

If any capture fails, call `browser_close_all`, report the affected viewport
and concrete reason, preserve useful capture files, and stop before CLI
publication unless the user explicitly chooses a reduced set. After all
captures succeed, call `browser_close_all` before building or publishing the
manifest.

## 4. Build one logical screenshot

Collect immutable values:

```bash
git rev-parse --short=12 HEAD
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

Use the URL path or concise screen name as `page`. Use one concise version
label as `title`. Every selected image entry must repeat exactly the same
`page` and `title`; only `file` and `viewport` differ. Write and inspect one
version-1 manifest beneath the private directory.

## 5. Publish and report

Run exactly one shared `screenote ... snapshot --manifest ...` command. On a
zero exit and terminal `snapshot_ready` event:

- report the captured viewports and project name;
- return `review_url` and explain that device tabs switch variants;
- mention any `cap_fired` or `unsettled_poll` rows;
- tell the user to invoke the `feedback` skill after annotation;
- remove the private directory.

On CLI failure, show the JSON error and preserve the unchanged manifest and
captures so the same command can resume.
