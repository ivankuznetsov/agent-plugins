---
name: screenote
description: Capture a page at desktop/tablet/mobile viewports and upload to Screenote for human annotation
metadata:
  argument: "[desktop|tablet|mobile] [url-or-description]"
---

# Screenote — Visual Feedback Loop

You are executing the Screenote skill. This connects Codex to Screenote for visual feedback: screenshot a page at three viewports by default (desktop, tablet, mobile) and upload them as one logical Screenshot that the human can annotate per-viewport.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `feedback` → tell the user: "Feedback has moved to its own command. Run `$screenote:feedback` instead." Stop.
- If the argument starts with `desktop`, `tablet`, or `mobile` → **single-viewport mode**: capture only that viewport (strip the keyword from the argument; the rest is the URL/description).
- Otherwise → **multi-viewport mode (default)**: capture all three viewports (desktop + tablet + mobile) as one Screenshot.

## Viewport Dimensions

Fixed defaults (match Screenote server's canonical set):

| Viewport | Dimensions | Notes |
|---|---|---|
| `desktop` | **1280 × 800** | Playwright's default desktop |
| `tablet`  | **768 × 1024** | iPad mini |
| `mobile`  | **390 × 844** | iPhone 14 |

---

## Project Cache

Call `list_projects` to verify the MCP connection and get the current project list. If the call fails with an auth error, tell the user to authorize the Screenote MCP server and stop.

Then check for a cached project selection:

1. Try to read `.screenote/screenote-cache.json` (relative to cwd). If it is missing, try the legacy `.claude/screenote-cache.json` path for backward compatibility. If a cache file exists and contains valid JSON with `project_id` and `project_name`, AND that `project_id` appears in the `list_projects` response, use that project and skip the "Pick a Project" step. Do not announce the cached selection.
2. If the cache is missing, invalid, or the `project_id` is not in the `list_projects` response (stale cache), delete the stale cache file if it exists and proceed with the normal "Pick a Project" step below. After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.screenote/screenote-cache.json` (create the `.screenote/` directory if needed).

---

## Capture Mode

The user provided a URL or page description. Your job: screenshot it at the chosen viewport(s), upload to Screenote, return the annotation URL.

### Step 1: Pick a Project

**Check the Project Cache first** (see Project Cache section above). The `list_projects` call has already been made there. If the cache provides a valid project, skip to Step 2.

If no cache hit, determine the **local project name** from the current working directory (e.g., the repo/folder name). Use the project list already fetched in the Project Cache step. Always refer to projects by **name** — use `id` only internally for API calls.

**Matching logic:**
- If a Screenote project name matches the local project name (case-insensitive), use it automatically
- If no match is found (even if there's only one project), ask the user: list existing project names and offer to create a new one matching the local project name via the `create_project` MCP tool

After successful selection, write `{ "project_id": <id>, "project_name": "<name>" }` to `.screenote/screenote-cache.json`.

### Step 2: Resolve the URL

- If the argument looks like a full URL (starts with `http`), use it directly
- If it looks like a relative path (e.g., `/login`, `dashboard`), prepend `http://localhost:3000/`
- If it's a description (e.g., "login page"), figure out the URL from context (check routes, running servers, etc.)

### Step 3: Request Upload URLs

Decide which viewports to capture:

- **Multi-viewport mode (default)**: `[desktop, tablet, mobile]`
- **Single-viewport mode**: just the one the user named (`[desktop]`, `[tablet]`, or `[mobile]`)

Call the `create_multi_viewport_screenshot` MCP tool once:

```
Tool: create_multi_viewport_screenshot
Arguments:
  project_id: <from Step 1>
  page_name: <URL path, e.g. "/login", "/settings/profile">
  title: <version label — use the current date (e.g., "2025-06-15") or a short descriptor>
  viewports:
    - { viewport: "desktop", mime_type: "image/png" }
    - { viewport: "tablet",  mime_type: "image/png" }
    - { viewport: "mobile",  mime_type: "image/png" }
```

(Include only the viewports you decided on — single-viewport mode sends one array entry.)

The response returns:

```
{
  "screenshot_id": 123,
  "page_id": 45,
  "annotate_url": "https://screenote.ai/screenshots/123",
  "uploads": [
    { "viewport": "desktop", "upload_url": "https://...", "token": "..." },
    { "viewport": "tablet",  "upload_url": "...",        "token": "..." },
    { "viewport": "mobile",  "upload_url": "...",        "token": "..." }
  ]
}
```

Only `screenshot_id` and `annotate_url` are used downstream; `page_id` is returned for debugging. Drive the capture loop from `uploads[i].viewport` — that field is authoritative for mapping bytes to viewport.

Capture screenshots *after* requesting upload URLs so tokens don't expire mid-capture.

### Step 4: Capture and Upload Each Viewport

This section is the canonical capture-and-upload procedure. `/snapshot` references it per-route.

#### 4a. Validate the response before shelling out

Before any `curl`, reject a response that could smuggle shell metacharacters through the instructions below:

1. Parse the `SCREENOTE_URL` env var (or default `https://screenote.ai`) from `.mcp.json` to get the **expected host** (e.g., `screenote.ai`, or `localhost:3005` in dev).
2. For each entry in `uploads`, assert:
   - `upload_url` starts with `https://` (or `http://` if the expected host is `localhost`) and parses as a URL whose host equals the expected host. Otherwise abort with an error.
   - `viewport` is exactly one of `desktop`, `tablet`, `mobile`. Otherwise abort.

Never interpolate server-returned strings directly into shell commands — always go through a shell variable (see 4c).

#### 4b. Set up a per-invocation temp dir

```bash
SCREENOTE_DIR=$(mktemp -d /tmp/screenote-XXXXXX)
```

Fixed `/tmp/...` paths would collide with concurrent `/screenote` runs and are a symlink-attack target on shared machines; `mktemp -d` avoids both.

#### 4c. Capture and upload each viewport, serially

Browser automation usually shares a single browser context, so do **not** parallelize. Use the browser automation tools available in the current Codex environment, such as Playwright MCP or an installed browser automation skill. If no browser automation tool is available, stop and tell the user to enable one before capturing. For each `entry` in `uploads`, in order:

1. **Resize** via `browser_resize` to the dimensions from the Viewport Dimensions table above, keyed on `entry.viewport`.
2. **Navigate** via `browser_navigate` to the URL. Fresh navigate per viewport — safer for SPAs that read viewport at mount time than a resize-only flow.
3. **Wait** via `browser_wait_for` for dynamic content (loading spinners, skeleton screens) to settle.
4. **Screenshot** via `browser_take_screenshot` with `filename` = `$SCREENOTE_DIR/<viewport>.png` and `type` = `png`.
5. **Upload** via curl using a shell variable for the URL — do not interpolate the value inline:
   ```bash
   UPLOAD_URL='<validated upload_url from 4a>'
   curl -fsS -X PUT -H 'Content-Type: image/png' \
     --data-binary @"$SCREENOTE_DIR/<viewport>.png" \
     "$UPLOAD_URL"
   ```
   `-f` turns 4xx into a non-zero exit so the retry path (4d) can trigger.
6. **Track progress**: print `[<viewport>] uploaded`.

#### 4d. Token-expiry retry

If any `curl` exits non-zero with a 4xx status (token expired or rejected), call `create_multi_viewport_screenshot` **once** again for this same `(project_id, page_name, title)` to get fresh upload URLs, re-validate them (4a), and retry the remaining viewports from the start of the failed one. On a second failure, record the viewport as failed and continue with the next one; include failures in the Step 5 summary.

Note: re-calling `create_multi_viewport_screenshot` with the same `page_name`/`title` will create a new Screenshot grouped under the same Page. Acceptable for single-page retry; for batch runs (`/snapshot`), callers should decide whether to retry per-route or skip.

#### 4e. Clean up

```bash
rm -rf "$SCREENOTE_DIR"
```

Run cleanup whether capture succeeded or failed.

### Step 5: Report to User

Tell the user:
- The viewports that were uploaded (e.g. "Uploaded desktop / tablet / mobile")
- Say "Uploaded to **<project_name>**" and provide the **annotate_url** so they can open it in the browser and add annotations
- Mention they can switch between viewports in Screenote using the device-icon toolbar
- Tell them to run `/feedback` when they're done annotating
- If any viewport failed after retry, list it explicitly
