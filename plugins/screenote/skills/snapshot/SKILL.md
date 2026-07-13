---
name: snapshot
description: Discover an app's routes, capture each page at desktop/tablet/mobile, and publish one reviewable batch through the Screenote CLI
metadata:
  argument: "[desktop|tablet|mobile] [base-url or description]"
---

# Snapshot — Full App Visual Snapshot

Discover the navigable application, capture the confirmed route set, and
publish all images as one resumable Screenote snapshot through the OAuth CLI.

Read and follow [`../../references/cli.md`](../../references/cli.md) completely
before running this workflow. Also use the viewport dimensions in
[`../screenote/SKILL.md`](../screenote/SKILL.md).

## Parse the request

An initial `desktop`, `tablet`, or `mobile` selects one viewport. Otherwise use
all three. The remainder is the base URL or application description.

## 1. Preflight and project

Run the shared CLI/OAuth capability checks and project-selection procedure
before browser work.

Collect immutable snapshot metadata:

```bash
git rev-parse --short=12 HEAD
git log -1 --format=%s
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

The short commit is the manifest `git_commit`. Keep the timestamp unchanged
through retries.

## 2. Resolve the base URL

Use an explicit full URL unchanged. Otherwise detect the running server from
listening processes and project configuration (`package.json`, Rails routes,
Django/Phoenix/Go setup, and similar evidence). Ask the user when detection is
ambiguous; do not guess a port.

## 3. Discover routes

Combine static and runtime evidence.

Static discovery:

- React Router: `<Route>`, route arrays, `createBrowserRouter`.
- Next/Remix and other file routers: `pages/`, `app/`, route modules.
- Vue/Angular: router configuration and route arrays.
- Rails/Django/Phoenix/Express: navigable GET route definitions.
- README, sitemap, and route documentation.

Runtime discovery:

1. Resize to desktop before discovery so responsive navigation is not hidden.
2. Open the base URL and collect same-origin links from the rendered page.
3. Merge and deduplicate normalized paths; exclude sign-out, mutation, asset,
   API, mail, and destructive links.

Mark parameterized paths as dynamic. Ask for sample ids/slugs or omit them.
Present a numbered route list and let the user confirm, add, or remove routes
before capture.

Calculate `routes × viewports`. If it exceeds the manifest limit of 100, ask
the user to reduce routes or select one viewport now.

## 4. Authentication for the reviewed app

This is separate from Screenote OAuth. Prefer, in order:

1. an already authenticated browser session;
2. test/staging credentials supplied through environment variables;
3. a limited test account the user explicitly chooses.

Warn that credentials typed in chat become conversation data. Capture public
pages before login, authenticate once, then capture private pages with the same
browser context.

## 5. Capture every page

Create one private invocation directory using the shared contract. Capture
serially. For each confirmed route and viewport:

1. Resize to the canonical dimensions.
2. Navigate afresh and wait for stable content.
3. Capture a full-page PNG named with a safe route index and viewport, for
   example `003-mobile.png`.
4. Record the exact route, common logical title, relative filename, and
   viewport for the manifest.

Capture useful 404/error states but label them in the report. Skip timeouts
after one retry and report them. If the browser process fails, preserve the
completed files and offer to resume capture before publication.

## 6. Build one complete manifest

Use one `images` entry per captured file. Use the normalized route as `page`.
Use one logical title per route, such as `App Snapshot — <date> — <commit>`.

All viewport variants of a route must repeat the exact same `page` and `title`.
Never put a viewport or device name in either field. The viewport belongs only
in `viewport` and the filename. Inspect the completed JSON and verify there are
no duplicate `(page, title, viewport)` tuples.

Do not publish per-route or per-viewport manifests. The complete run is one
manifest and one CLI invocation.

## 7. Publish and summarize

Run the shared `screenote ... snapshot --manifest ...` command once. Success
requires exit status zero and a final `snapshot_ready` event.

Report:

- date and commit;
- selected project and viewports;
- captured/expected page and image counts;
- captured routes, skipped routes, and error states;
- the terminal `review_url`;
- how to invoke the `feedback` skill after annotation.

Remove the private directory on success. Preserve it with the unchanged
manifest on failure so the CLI can resume safely.
