---
name: screenote
description: Capture a page or publish existing PNG/JPEG screenshots with the Screenote CLI for human annotation
metadata:
  argument: "[desktop|tablet|mobile] [url-or-description|image-path...]"
---

# Screenote — Visual Feedback Loop

Capture one page with the bundled Browser Use adapter or accept explicit local
PNG/JPEG files, publish the selected viewport files as one logical screenshot
through the OAuth CLI, and return its review URL.

Read and follow [`../../references/cli.md`](../../references/cli.md) completely
before running this workflow. Its CLI/OAuth, project cache, existing-image,
Browser Use, manifest, cleanup, and error rules are mandatory. Browser Use is
capture-only and is not required for existing-image publication; every
Screenote operation uses the CLI.

## Parse the request

- If the argument starts with `feedback`, direct the user to the `feedback`
  skill and stop.
- Treat one or more explicit readable `.png`, `.jpg`, or `.jpeg` paths, including
  host-exposed attachment paths, as existing-image mode. A named image path that
  is missing or unreadable is an input error; never reinterpret it as a page.
- Otherwise treat the remainder as a URL, route path, or page description and
  use browser-capture mode.
- In browser-capture mode, an initial `desktop`, `tablet`, or `mobile` selects
  only that viewport; otherwise capture all three.
- In existing-image mode, an initial viewport assigns a single file to that
  viewport. Without a prefix, infer multiple files from unambiguous filename
  tokens or canonical pixel widths. A single otherwise-unclassified image is
  `desktop`. Ask the user only when multiple files remain ambiguous or map to a
  duplicate viewport.

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

## Existing-image mode

Use this mode only for image paths the user explicitly supplied or shared. Do
not scan the repository, temporary directories, browser downloads, or prior
capture folders looking for candidates.

Skip Browser Use discovery, preflight, navigation, and capture entirely. A
Browser Use startup or viewport error cannot block this mode.

1. Create the private invocation directory from the shared contract.
2. Apply the shared existing-image checks to every source file. Reject the
   whole set before publication if any file is not a readable regular file,
   exceeds the size limit, has bytes that are not PNG/JPEG, cannot be decoded,
   or produces an ambiguous/duplicate viewport assignment.
3. Inspect each image with the environment image viewer, then copy its bytes
   unchanged into the private directory using canonical names such as
   `desktop.png` or `mobile.jpg`. Quote every source path with the shared
   dynamic-value rules. The manifest must never contain the original local
   path.
4. If a conversation attachment is visually available but the host does not
   expose a readable local path, explain that the CLI needs a file path and ask
   the user to save or attach it in a file-backed form. Do not start Browser Use
   as a substitute.
5. Continue at **Build one logical screenshot**. Report the result as published
   existing images, not as a fresh browser capture.

## Browser-capture mode

### 2. Resolve the page

- Use a complete `http://` or `https://` URL unchanged.
- Resolve a relative path against the running development server. Detect the
  real server and port from processes and project configuration; do not assume
  port 3000 without evidence.
- Resolve a natural-language description from application routes.
- For application login, prefer the visible ephemeral browser window or
  environment-provided test credentials. Never request production credentials
  in chat.

### 3. Preflight and capture

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

For browser capture, use the URL path or concise screen name as `page`. For
existing images, use a user-supplied screen name or a concise basename-derived
name. Use one concise version label as `title`. Every selected image entry must
repeat exactly the same `page` and `title`; only `file` and `viewport` differ.
Write and inspect one version-1 manifest beneath the private directory.

## 5. Publish and report

Run exactly one shared `screenote ... snapshot --manifest ...` command. On a
zero exit and terminal `snapshot_ready` event:

- report the published viewports, input mode, and project name;
- return `review_url` and explain that device tabs switch variants;
- for browser capture, mention any `cap_fired` or `unsettled_poll` rows;
- tell the user to invoke the `feedback` skill after annotation;
- remove the private directory.

On CLI failure, show the JSON error and preserve the unchanged manifest and
image copies so the same command can resume.
