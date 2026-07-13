---
name: feedback
description: Retrieve and act on visual annotations through the Screenote CLI
metadata:
  argument: "[desktop|tablet|mobile] [page-name or version]"
---

# Feedback — Retrieve Visual Annotations

Read open Screenote annotations, inspect their viewport-specific crops, and
optionally comment and resolve them after fixing the code.

Read and follow [`../../references/cli.md`](../../references/cli.md) completely
before running this workflow. All Screenote access goes through the OAuth CLI.

## Parse the request

If the first token is exactly `desktop`, `tablet`, or `mobile`, consume it as
the viewport filter. Treat the remainder as a case-insensitive page/version
hint. Otherwise use the full argument as the hint with no viewport filter.

Never interpret a viewport token as part of a page title.

## 1. Preflight and select a project

Run the shared CLI preflight, OAuth, and project-cache procedure. If the fresh
project list is empty, tell the user to capture a page with the `screenote`
skill first.

Create a private temporary directory for annotation detail JSON and crop files.

## 2. Select a page and version

List pages with the project-scoped `page list` command from the shared
contract.

- No pages: explain that this project has no captures and stop.
- One page: select it.
- Multiple pages: auto-select only one unambiguous hint match; otherwise show
  names and version counts and ask the user.

List versions with
`screenshot list --page "<page-id-from-page-list>" --limit 100 --offset 0`,
replacing the quoted placeholder with the observed page id in that same tool
call. Follow the shared contract's pagination loop to exhaustion before
choosing a version.

- No versions: explain that the page has no captured version and stop.
- One version: select it.
- Multiple versions: auto-select only one unambiguous hint match; otherwise
  show titles and ask the user.

## 3. Fetch open annotations

Run
`annotation list --screenshot "<screenshot-id-from-screenshot-list>" --status open --limit 100 --offset 0`,
replacing the quoted placeholder with the observed screenshot id. Add
`--viewport "<selected-viewport>"` when the request selected a viewport.
Follow `pagination.total` to exhaustion before deciding that there are no more
annotations or presenting feedback.

If no annotations are open, return the screenshot's review URL when available
and stop.

For every annotation, run `annotation get --crop-file` as documented in the
shared contract. Inspect the resulting PNG with the environment's image viewer.
Do not place encoded crop data in the conversation. If the command returns the
exact JSON error code `crop_unavailable`, retain the metadata from `annotation list`
and mark that annotation's crop as unavailable. Continue with the remaining annotations.
Any other detail or crop error stops the workflow.

## 4. Present feedback

Use the heading:

`Feedback for <project> — <page> — <version>`

Group annotations by Desktop, Tablet, and Mobile when more than one viewport is
present. For each annotation show its id, viewport, point/region coordinates,
author, comment, and cropped image. Preserve the user's wording exactly.

## 5. Fix, comment, and resolve

Ask whether to fix one annotation, all annotations, reply without a code
change, or capture a verification screenshot.

For every addressed annotation:

1. Make and verify the requested code change when needed.
2. Post an explanatory reply with `comment add`. Include what changed and the
   relevant file/location, or explain why the behavior is intentional.
3. Only after the reply succeeds, run `annotation resolve` with a short
   resolution note.
4. Treat `already_resolved` as success. For other failures, follow the shared
   contract's error rules and never silently resolve without the reply.

Remove the temporary crop directory after success. Preserve it while reporting
an error only when it helps the user inspect the failed workflow.
