---
name: snapshot
description: Take a full app snapshot — discover all routes, screenshot every page at desktop/tablet/mobile viewports, and upload to Screenote with date and commit metadata
metadata:
  argument: "[desktop|tablet|mobile] [base-url or description]"
---

# Snapshot — Full App Visual Snapshot

You are executing the Snapshot skill. This captures a complete visual snapshot of an application: discover all routes, screenshot every page at three viewports (desktop, tablet, mobile) by default, and upload them to Screenote as a batch. Each screenshot is tagged with the current date and the last git commit hash.

This is separate from the single-page `/screenote` command. Use `/snapshot` when you need a full picture of the entire app.

Authentication is handled automatically via OAuth 2.1 — the plugin's `.mcp.json` configures the MCP server connection. No API key needed.

## Mode Detection

Parse the user's argument:

- If the argument starts with `desktop`, `tablet`, or `mobile` → **single-viewport mode**: capture only that viewport (strip the keyword from the argument; the rest is the base URL/description).
- Otherwise → **multi-viewport mode (default)**: capture all three viewports per route.

## Viewport Dimensions

Use the canonical Viewport Dimensions table from the `/screenote` skill (`skills/screenote/SKILL.md` § Viewport Dimensions). Single source of truth — do not restate the pixel values here.

---

## Step 1: Pick a Project

Follow the **Project Cache** and **Pick a Project** procedure from the `screenote` skill (`codex-skills/screenote/SKILL.md`). The logic is identical: call `list_projects` first (auth gate), then check `.screenote/screenote-cache.json` with legacy `.claude/screenote-cache.json` fallback, match by local project name, or prompt the user.

---

## Step 2: Collect Metadata

Gather the date and last commit information. Run:

```bash
echo "DATE=$(date +%Y-%m-%d)" && git log -1 --format="COMMIT=%h %s"
```

Parse the output to extract:
- `snapshot_date` — e.g., `2025-06-15`
- `commit_short` — short hash, e.g., `a1b2c3d`
- `commit_message` — first line of commit message

Compose a **snapshot label**:
```
App Snapshot — <snapshot_date> — <commit_short>
```

This label will be used as a prefix in every screenshot title.

---

## Step 3: Resolve the Base URL

The user provides either a base URL or a description of the app.

- If the argument looks like a full URL (starts with `http`), use it as the base URL
- If it looks like a relative path, prepend the detected base URL (see below)
- If it's a description or empty, detect the base URL from the project

**Port detection:** Do not assume `localhost:3000`. Infer the port from the project's framework:
- Check for a running dev server first (e.g., `lsof -i -P -n | grep LISTEN` or similar)
- If nothing is running, infer from project files: `package.json` scripts (Next.js/Vite/CRA → 3000-5173), `manage.py` (Django → 8000), `config/routes.rb` (Rails → 3000), `mix.exs` (Phoenix → 4000), `go.mod` (Go → 8080)
- If detection fails, ask the user for the base URL instead of guessing

Store this as `base_url` (no trailing slash).

---

## Step 4: Discover All Routes

This is the core discovery step. Use **multiple strategies** to build a comprehensive route list.

### Strategy A: Static Analysis of the Codebase

Search the local project files for route definitions. Look for common patterns depending on the framework:

**React Router / React:**
- Search for `<Route`, `path=`, `createBrowserRouter`, `createRoutesFromElements` in `*.tsx`, `*.jsx`, `*.ts`, `*.js` files
- Check for file-based routing in `app/routes/`, `src/pages/`, `src/app/` directories (Next.js, Remix, etc.)

**Next.js:**
- Scan `pages/` or `app/` directory structure — each file/folder is a route
- `page.tsx`, `page.jsx`, `page.js` files define routes in the App Router

**Vue Router:**
- Search for `routes:` arrays, `path:` definitions in router config files

**Angular:**
- Search for `RouterModule.forRoot`, `Routes` arrays

**Express / Backend:**
- Search for `app.get(`, `router.get(` patterns only — POST/PUT/DELETE endpoints are API handlers, not navigable pages
- Look for route definition files

**Django:**
- Search for `urlpatterns`, `path(`, `re_path(` in `urls.py` files

**Rails:**
- Check `config/routes.rb`

**General:**
- Search for any file named `routes.*`, `router.*`, `urls.*`
- Look at the project's README or docs for route listings
- Check for sitemap files

Build a list of route paths (e.g., `/`, `/login`, `/dashboard`, `/settings`, `/users/:id`).

### Strategy B: Runtime Discovery (supplement)

After static analysis, optionally navigate to the base URL and extract links.

1. Resize the browser to **desktop** (see `/screenote` Viewport Dimensions) before any browser interaction. Discovery must run at desktop width regardless of Mode Detection — at mobile width, responsive apps commonly collapse the primary nav into a hamburger menu, which hides links from the accessibility tree and causes routes to be silently omitted from the snapshot.
2. Navigate to `base_url` with `browser_navigate`
3. Use `browser_snapshot` to get the page's accessibility tree
4. Extract all internal links (same-origin `<a href>` values)
5. Add any new routes not found in static analysis

### Handling Dynamic Routes

For routes with parameters (e.g., `/users/:id`, `/posts/[slug]`):
- Note them in the route list but mark them as **dynamic**
- Ask the user if they want to provide sample values, or skip dynamic routes
- If the user provides values, substitute them; otherwise skip those routes

### Present the Route List

Show the user the discovered routes in a numbered list:

```
Discovered 12 routes:

 1. / (home)
 2. /login
 3. /signup
 4. /dashboard
 5. /dashboard/analytics
 6. /settings
 7. /settings/profile
 8. /settings/billing
 9. /users (list)
10. /users/:id (dynamic — will skip unless sample ID provided)
11. /admin
12. /admin/settings
```

Ask the user:
- **Confirm** the list, or add/remove routes
- Provide sample values for any dynamic routes they want included
- Identify which routes require **authentication** (or let the agent discover this in the next step)

---

## Step 5: Decide Which Viewports to Capture

Based on Mode Detection:

- **Multi-viewport mode (default)**: `[desktop, tablet, mobile]` — three captures per route
- **Single-viewport mode**: one of `[desktop]`, `[tablet]`, `[mobile]`

Store this as `viewports_to_capture` for the capture loop.

Strategy B (runtime discovery) and the authentication flow both run at desktop width — see Step 4 Strategy B and Step 6 below. Per-viewport captures happen only in Step 7.

---

## Step 6: Handle Authentication

Some pages require login. Detect and handle this.

**Security note — read before asking the user for credentials:** Anything the user types in response to "how should I log in?" will be visible in the conversation context (and any transcripts/exports derived from it). Before asking, recommend these safer paths in order:

1. **Pre-authenticated browser session** (preferred): ask the user to log in manually in the Playwright browser before running `/snapshot` — the session cookies persist and no credentials enter the transcript.
2. **Environment variables**: have the user put the credentials in env vars and reference them in the login flow without echoing the values.
3. **Test/staging account with limited permissions**: only if no other option exists.

Only if the user explicitly opts into form login with typed credentials should you proceed with the Detection flow below.

### Detection
- Ask the user: "Does this app require authentication? If so, how should I log in?"
- Common options:
  - **Form login**: Navigate to login page, fill in credentials (user provides username/password)
  - **Already logged in**: If the browser session already has auth cookies/tokens
  - **No auth needed**: All pages are public

### Login Flow (if needed)

1. Navigate to the login page using `browser_navigate`
2. Use `browser_snapshot` to see the form fields
3. Fill in credentials using `browser_type` for each field
4. Submit the form using `browser_click`
5. Wait for redirect/confirmation using `browser_wait_for`
6. Verify login succeeded by checking the resulting page

**Important:** Perform login **once**. The browser session will maintain cookies/tokens for subsequent page visits.

### Route Ordering and Login Timing

Split the screenshot loop into two phases so public pages are captured in their unauthenticated state:

1. **Phase 1 — Public pages** (login form, signup form, landing pages): screenshot these **before** logging in
2. **Login step**: perform the login flow (if authentication is needed)
3. **Phase 2 — Authenticated pages** (dashboard, settings, admin, etc.): screenshot these **after** logging in

---

## Step 7: Screenshot Each Page

Loop through the route list. For each route, perform the canonical capture-and-upload procedure from `/screenote` Step 4 (`skills/screenote/SKILL.md` § Step 4: Capture and Upload Each Viewport). That section covers response validation, the per-invocation temp dir, serial capture, safe curl invocation, token-expiry retry, and cleanup — do not re-implement any of those details here.

This skill adds the **per-route orchestration** on top:

For each route (index `i`, path `<route_path>`):

1. **Request upload URLs** — one call per route, all viewports in one shot:
   ```
   Tool: create_multi_viewport_screenshot
   Arguments:
     project_id: <from step 1>
     page_name: "<route_path>"
     title: "<snapshot_label>"  # e.g., "App Snapshot — 2025-06-15 — a1b2c3d"
     viewports: <viewports_to_capture as { viewport, mime_type: "image/png" } entries>
   ```

2. **Run the `/screenote` Step 4 capture-and-upload procedure** against the returned `uploads` array. Use route-scoped filenames inside the mktemp dir (e.g. `$SCREENOTE_DIR/<i>-<viewport>.png`) so concurrent routes don't clobber each other if future versions parallelize.

3. **Track progress**: after each route completes, print a line like `[3/12] /dashboard — desktop, tablet, mobile uploaded`.

Capture is serial — Playwright MCP shares one browser context.

### Error Handling

- If a page returns a 404 or error, capture it anyway (the error state is useful for review) but note it in the summary
- If a page requires auth and you're not logged in (redirects to login), note it and suggest the user provide credentials
- If navigation times out, skip the page and note it in the summary
- Token-expiry retries are already handled inside the `/screenote` Step 4 procedure — skipped viewports surface back here and should be recorded per-route in the summary
- **If the process fails mid-batch** (API error, browser crash, network issue): report which pages were successfully uploaded versus which remain, clean up the temp directory, and offer to resume from the last failed page

---

## Step 8: Summary Report

After all pages are captured, present a summary grouped by route:

```
App Snapshot Complete

Date: 2025-06-15
Commit: a1b2c3d — "Fix header alignment"
Viewports: Desktop + Tablet + Mobile (or "Desktop only" / "Mobile only" / etc.)
Project: <project_name>
Pages captured: 11/12 × 3 viewports = 33 screenshots

Uploaded pages:
 1. /
 2. /login
 3. /signup
 4. /dashboard
 5. /dashboard/analytics
 6. /settings
 7. /settings/profile
 8. /settings/billing
 9. /users
10. /admin
11. /admin/settings

Skipped:
 - /users/:id (dynamic route — no sample value provided)

Open Screenote to review and annotate the snapshots.
Run /feedback when ready.
```

---

## Key Differences from /screenote

| Feature | `/screenote` | `/snapshot` |
|---|---|---|
| Pages | Single page | All discovered pages |
| Route discovery | User provides URL | Agent explores codebase |
| Auth handling | Not handled | Login flow before capturing |
| Metadata | Simple title | Date + commit hash in every title |
| Output | One screenshot + annotate link | Batch upload + summary report |
