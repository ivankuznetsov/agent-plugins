---
name: screenote
description: Capture a page at desktop/tablet/mobile viewports and publish it with the Screenote CLI for human annotation
metadata:
  argument: "[desktop|tablet|mobile] [url-or-description]"
---

# Screenote — Visual Feedback Loop

Capture one page with browser automation, publish all selected viewport images
as one logical Screenote screenshot through the OAuth CLI, and return its review
URL.

Read and follow [`../../references/cli.md`](../../references/cli.md) completely
before running this workflow. Its preflight, OAuth, project cache, manifest,
error, and cleanup rules are mandatory.

## Parse the request

- An initial `desktop`, `tablet`, or `mobile` selects that single viewport.
- Otherwise capture desktop, tablet, and mobile.
- If the argument starts with `feedback`, direct the user to the `feedback`
  skill and stop.
- The remainder is a URL, path, or page description.

Canonical viewport dimensions are:

| Viewport | Dimensions |
| --- | --- |
| desktop | 1280 × 800 |
| tablet | 768 × 1024 |
| mobile | 390 × 844 |

## 1. Preflight and select a project

Run the CLI/OAuth preflight and project-selection procedure from the shared CLI
contract. Do not capture anything until the CLI capability checks, OAuth, and
fresh project lookup succeed.

## 2. Resolve and open the page

- Use a full `http://` or `https://` URL unchanged.
- Resolve a relative path against the running development server. Detect the
  actual server/port from processes and project configuration; do not assume
  port 3000 when evidence says otherwise.
- Resolve a natural-language description from application routes.
- If the reviewed app needs login, prefer an already authenticated browser
  session or environment-provided test credentials. Do not ask the user to put
  production credentials in chat.

## 3. Capture selected viewports

Create the private invocation directory from the shared contract. For each
selected viewport, serially:

1. Resize to the canonical dimensions.
2. Navigate afresh to the resolved URL.
3. Wait for loading indicators and dynamic content to settle.
4. Capture a full-page PNG named `<viewport>.png` in the private directory.

If a capture fails, report the viewport and stop before publication. Do not
publish a partial logical screenshot unless the user explicitly requests it.

## 4. Build one manifest

Collect:

```bash
git rev-parse --short=12 HEAD
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

Use the URL path (or a concise screen name) as `page`. Use one concise version
label as `title`, such as the date plus short commit. Every selected viewport
entry must repeat exactly the same `page` and `title`; only `file` and
`viewport` differ. The shared contract's logical-title rule is load-bearing.

Write one version-1 manifest beneath the private directory and inspect its JSON
before publication.

## 5. Publish and report

Run exactly one `screenote ... snapshot --manifest ...` command as specified in
the shared contract. On the terminal `snapshot_ready` event:

- report the uploaded viewports and selected project name;
- return `review_url` so the user can annotate immediately;
- explain that device tabs switch between variants;
- tell the user to invoke the `feedback` skill when annotation is complete;
- remove the private directory.

On failure, show the CLI JSON error and preserve the manifest/captures for an
unchanged resume.
