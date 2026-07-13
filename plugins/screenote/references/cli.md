# Screenote CLI contract

Read this file completely before running any Screenote skill. It is the shared
contract for installation, OAuth, project selection, publication, and feedback.

## Preflight and OAuth

Use the public CLI for every Screenote operation. The production base URL is
`https://screenote.ai`; honor `SCREENOTE_BASE_URL` when the user intentionally
points at another deployment. Agent tool calls do not share shell state, so
every Screenote command repeats the inline default instead of relying on a
variable assigned by an earlier call.

```bash
command -v screenote
screenote project create --help
screenote annotation resolve --help
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" project list
```

If `screenote` is missing or either capability check fails, explain that the
current public CLI is required and offer to install or upgrade it:

```bash
go install github.com/ivankuznetsov/screenote-cli/cmd/screenote@latest
```

This requires Go 1.26 or newer and a Go bin directory on `PATH`. Do not claim
the workflow is available until the capability checks pass.

If `project list` reports that OAuth login is required, authenticate:

```bash
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" login
```

When the current shell cannot open a browser (SSH, tmux, a container, or a
headless runner), use device authorization:

```bash
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" login --device
```

Surface the authorization URL and short code to the user, keep the login
process running, and continue only after it succeeds. Screenote stores and
refreshes OAuth credentials itself. Never ask the user to paste a credential,
never copy the credential file into a project, and never read its contents.

Run `project list` again after login. For authentication or authorization
errors, stop and show the CLI's JSON error. Do not silently fall back to another
transport.

## Project selection and cache

Every invocation starts from the fresh JSON returned by:

```bash
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" project list
```

Then resolve a project as follows:

1. Read `.screenote/screenote-cache.json` when present. The supported shape is
   `{ "project_id": 7, "project_name": "my-app" }`.
2. Use it only when that id is still present in the fresh project list.
3. Otherwise remove the stale cache and case-insensitively match the current
   repository directory name against project names.
4. If there is one exact match, select it. Otherwise show the project names and
   ask the user to choose. Offer to create a project when no appropriate match
   exists:

   ```bash
   screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" project create --name "my-app"
   ```

5. After selection, write only the id and name to
   `.screenote/screenote-cache.json`.

Pass the selected id explicitly on every project-scoped command. Replace each
quoted `<...>` placeholder with the value observed from the immediately
preceding CLI response before running the command; never execute a placeholder
literally or expect it to expand from an earlier shell:

```bash
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" \
  --project "<project-id-from-fresh-project-list>" ...
```

Do not write a repository's project selection into the global CLI config.

## Browser capture

Screenote CLI publishes existing PNG/JPEG files; browser automation captures
them. Use the browser automation available in the current environment. If none
is available, stop and explain what is missing.

Canonical viewports:

| Viewport | Width | Height |
| --- | ---: | ---: |
| desktop | 1280 | 800 |
| tablet | 768 | 1024 |
| mobile | 390 | 844 |

Use a new private directory per invocation. Run this block as one shell call and
record the printed path as `<private-screenote-dir>` for later commands:

```bash
private_dir=$(mktemp -d "${TMPDIR:-/tmp}/screenote-XXXXXX")
chmod 700 "$private_dir"
printf '%s\n' "$private_dir"
```

Capture serially because browser environments commonly share one context. For
each image, resize, navigate afresh, wait for dynamic content to settle, and
write a PNG beneath the exact printed `<private-screenote-dir>` path. Preserve
authentication cookies between navigations when the reviewed application
requires login. Do not rely on `private_dir` existing in a later tool call.

## Snapshot manifest invariants

Publish captures with one version-1 manifest and one `snapshot` command:

```bash
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" \
  --project "<project-id-from-fresh-project-list>" \
  snapshot --manifest "<private-screenote-dir>/manifest.json"
```

The manifest contains a 7-40 character hexadecimal Git commit, an ISO 8601
timestamp with an explicit offset, and 1-100 images. Paths are relative to the
manifest and must stay within its directory.

One logical screenshot can have desktop, tablet, and mobile image variants.
Those entries must use exactly the same `page` and exactly the same `title`.
The viewport belongs only in `viewport` and, when useful, the filename. Never
append `desktop`, `tablet`, `mobile`, dimensions, or device punctuation to the
logical page/title.

Correct:

```json
{
  "version": 1,
  "git_commit": "7f3a1c9",
  "taken_at": "2026-07-13T20:30:00Z",
  "images": [
    {
      "page": "Public benchmark",
      "title": "Benchmark overview",
      "file": "benchmark-desktop.png",
      "viewport": "desktop"
    },
    {
      "page": "Public benchmark",
      "title": "Benchmark overview",
      "file": "benchmark-mobile.png",
      "viewport": "mobile"
    }
  ]
}
```

Wrong: titles such as `Benchmark overview — desktop` and
`Benchmark overview — mobile`. They create two logical screenshots instead of
two variants of one screenshot.

Build and inspect the complete manifest before publishing. Do not publish one
manifest per viewport or per page during a full-app snapshot. If the selected
routes multiplied by the viewport count exceeds 100, ask the user to reduce the
route set or choose one viewport before capturing.

`snapshot` emits JSON Lines. Treat the command as successful only when its exit
status is zero and its final event is `snapshot_ready`; return that event's
`review_url`. On failure, keep the directory and unchanged manifest so the same
command can resume. Remove the directory only after success.

## Feedback commands

Use these project-scoped CLI commands:

```bash
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" --project "<project-id-from-fresh-project-list>" page list
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" --project "<project-id-from-fresh-project-list>" screenshot list --page "<page-id-from-page-list>" --limit 100 --offset 0
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" --project "<project-id-from-fresh-project-list>" annotation list --screenshot "<screenshot-id-from-screenshot-list>" --status open --limit 100 --offset 0
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" --project "<project-id-from-fresh-project-list>" annotation get --annotation "<annotation-id-from-annotation-list>" --crop-file "<private-screenote-dir>/annotation-<annotation-id-from-annotation-list>.png"
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" --project "<project-id-from-fresh-project-list>" comment add --annotation "<annotation-id-from-annotation-list>" --body "<explanatory-reply>"
screenote --base-url "${SCREENOTE_BASE_URL:-https://screenote.ai}" --project "<project-id-from-fresh-project-list>" annotation resolve --annotation "<annotation-id-from-annotation-list>" --comment "<resolution-note>"
```

Both list commands are paginated. Read `pagination.total`, add the number of
returned records to `--offset`, and repeat with `--limit 100` until every
record has been collected. A response with no records before the collected
count reaches `pagination.total` is an error, not a completed list. Deduplicate
by id across pages. Never describe the first page as the complete version or
annotation set.

The crop file is local visual context. Inspect it with the environment's image
viewer; do not paste encoded image data into chat. If `annotation get` fails
with the exact JSON error code `crop_unavailable`, keep the annotation metadata
returned by `annotation list`, mark its visual crop as unavailable, and continue
with the remaining annotations. Any other detail or crop error stops the
workflow. Treat `already_resolved` as an idempotent success.

When addressing feedback, post the explanatory comment first and resolve only
after that command succeeds. For 401/403 errors, stop and re-authenticate. For
validation errors, correct the input. Retry a network/5xx comment once, then
stop; never resolve without the explanatory comment.

## Output discipline

Successful ordinary commands emit one JSON document. `snapshot` emits JSON
Lines. Errors emit JSON on stderr and a non-zero exit status. Parse JSON rather
than scraping human text, show server errors verbatim, and never print or log
OAuth credential material.
