---
name: feedback
description: Retrieve Screenote pages, screenshots, annotations, and private crops, then comment after applying a fix.
metadata:
  argument: "[desktop|tablet|mobile] [page-name-or-version]"
---

# Feedback — retrieve and act on annotations

Read and follow [the shared CLI contract](../../references/cli.md) completely.
The public grammar remains:

```text
feedback [desktop|tablet|mobile] [page-name-or-version]
```

Consume an initial viewport as a filter. Treat the remainder as a
case-insensitive page/version hint, never as a command or local path.

## Select project, page, and screenshot

Detect the CLI without installing or authenticating automatically. Run
`project list`; project precedence is `--project`, `SCREENOTE_PROJECT`, then
CLI config. Apply the shared exit 2 `missing_token` / `missing_project`, exit 3,
and other nonzero JSON handling. Noninteractive runs never prompt or open a
browser.

Run allowlisted `page list`. Select only one unambiguous hint match; otherwise
show choices interactively or stop noninteractively. Run paginated `screenshot
list --page <page-id> --limit 100 --offset <offset>` until the reported total
is exhausted. An empty page before the total is reached is an error.

## Retrieve annotations

Create a private `mktemp -d` directory mode `0700`; crop files are mode `0600`
and must be new paths beneath it. Run paginated `annotation list --screenshot
<id> --status open --limit 100 --offset <offset>`, adding `--viewport` only
when requested. Deduplicate ids across pages.

For each result, run allowlisted `annotation get --annotation <id> --crop-file
<new-private-png>`. Inspect the PNG with the environment's local image viewer;
never encode it into chat. `crop_unavailable` keeps the annotation metadata
and continues; any other nonzero result stops.

Present feedback grouped by viewport with id, coordinates, author, and the
user's comment preserved exactly.

## Fix and comment

Ask whether to fix one, all, reply without a code change, or capture a
verification image. For every addressed annotation:

1. Make and verify the requested code change when applicable.
2. Run allowlisted `comment add --annotation <id> --body <explanation>` with
   the body as one argv element. Never put credentials or shell interpolation
   in the body.
3. After the comment succeeds, tell the user to resolve the annotation in the
   Screenote UI. Final resolution is not an approved CLI action in this plugin.

Delete private crops after a successful flow. Preserve and report a crop only
when it materially helps diagnose a stopped flow. Never hide a failed comment
or claim the annotation is resolved automatically.
