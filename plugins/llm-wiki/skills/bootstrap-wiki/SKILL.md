---
name: bootstrap-wiki
description: Bootstrap an LLM-maintained wiki for the current project. Use when a user asks to create, initialize, or refresh a project wiki, LLM wiki, QMD wiki, or codebase knowledge base.
---

# Bootstrap LLM Wiki

Create a self-maintaining project wiki under `wiki/` for the current repository. Ground every page in actual source files and git history. Do not invent architecture, data models, routes, or decisions.

## Preconditions

- The current directory must be inside a git repository.
- QMD is optional but recommended. Use it when available; when missing, suggest installing it before falling back to `rg`.
- Merge existing agent settings and instructions. Do not overwrite existing config files blindly.
- Detect the main cross-project wiki when present. Check `~/wikis/master/wiki/` and `~/wikis/main/wiki/`.

## Step 1: Detect Project Shape

Read the project root and identify:

- Language/framework: `Gemfile`, `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `composer.json`, `pom.xml`, `build.gradle`, `*.sln`, `*.csproj`, or equivalents.
- Persistence: schema files, migrations, ORM models, SQL files, or absence of a database.
- Entry points: routes, API specs, CLI commands, GraphQL schemas, gRPC protos, or main files.
- Architecture: services, domain modules, packages, jobs, queues, middleware, dependency injection, or monorepo boundaries.
- Tests, dependency files, CI/CD, Docker, and deploy config.
- Main cross-project wiki: whether `~/wikis/master/wiki/` or `~/wikis/main/wiki/` exists. Prefer `~/wikis/master/wiki/` if both exist.

Adapt all later page names and source reads to what the project actually uses.

## Step 2: Create Wiki Skeleton

Create:

```bash
mkdir -p wiki raw/notes
```

Create or update:

- `wiki/index.md`: catalog of wiki pages.
- `wiki/log.md`: append-only log of wiki operations.
- `wiki/gaps.md`: open questions, missing coverage, and uncertainty.

Create stack-appropriate subdirectories only when useful, such as `models/`, `controllers/`, `services/`, `components/`, `packages/`, `modules/`, `commands/`, or `apis/`.

Add `.qmd/` to `.gitignore` if it is not already ignored.

## Step 3: Generate Grounded Pages

Read source files before writing. Prefer fewer, richer pages over many thin pages.

Before writing pages, search the main cross-project wiki when it exists. Read relevant pages such as `patterns.md`, `learnings.md`, `decisions.md`, `architecture.md`, and `index.md` if present. Use this context to align project wiki structure and note reusable patterns, but only cite or summarize cross-project facts from pages actually read.

Generate pages that apply to the project:

- `wiki/data-model.md`: persistent entities, relationships, constraints, indexes, and Mermaid ER diagram when useful.
- `wiki/routes.md`, `wiki/api.md`, or `wiki/commands.md`: external interaction surface.
- `wiki/architecture.md`: major components, boundaries, patterns, integrations, and deployment clues.
- `wiki/dependencies.md`: key dependency choices and visible rationale.
- `wiki/decisions.md`: lightweight ADRs from source and git history.
- `wiki/active-areas.md`: recently active areas from git history.
- Stack-specific pages under the subdirectories created in Step 2.

Use this frontmatter for pages where it helps:

```yaml
---
title: Page Title
type: architecture
source: path/to/source
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [architecture]
---
```

Include a one-sentence `TLDR` near the top of each page. Use `[[page-name]]` backlinks between related pages.

## Step 4: Build Gaps and Index

Read generated pages and compare them against the codebase.

Update `wiki/gaps.md` with:

- Source files or domains without wiki coverage.
- Patterns detected but not documented.
- Open questions and uncertainty.
- Areas that should be expanded later.

Update `wiki/index.md` with:

- Page count and date.
- Pages grouped by category.
- One-line summaries.

Append to `wiki/log.md`:

```markdown
## [TIMESTAMP] bootstrap

**Action:** Initial wiki bootstrap from codebase
**Pages created:** ...
**Pages updated:** ...
**Gaps found:** ...
**Source:** Codebase read + git history
```

## Step 5: Add Agent Instructions

Add a wiki section to the agent instruction file used by the current tool:

- Claude Code: `CLAUDE.md`
- Codex: `AGENTS.md`

Create the file if absent. Append, do not replace existing instructions.

Instruction content:

```markdown
## Wiki

This project has an LLM-maintained knowledge base in `wiki/`.

- `wiki/` — project knowledge pages maintained by the agent
- `wiki/index.md` — catalog of all pages
- `wiki/log.md` — append-only changelog
- `wiki/gaps.md` — known gaps and open questions
- `raw/notes/` — manually added reference material

Always check `wiki/` before answering questions about this project's architecture, patterns, or decisions.

When you learn something new about the project or make a decision:
1. Create or update the relevant page in `wiki/`
2. Update `wiki/index.md` if a new page was created
3. Append an entry to `wiki/log.md`

Never hallucinate. Ground everything in code or existing wiki pages. If unsure, note it in `wiki/gaps.md`.

Use `[[page-name]]` backlinks between wiki pages.

Query protocol:
1. Run `qmd query "<topic>"` or `qmd search "<topic>"` when QMD is available.
2. Fall back to `rg "<topic>" wiki/`.
3. Check the main cross-project wiki before making architectural decisions when it exists:
   - `~/wikis/master/wiki/`
   - `~/wikis/main/wiki/`
```

## Step 6: Hooks, Scheduled Automation, and QMD

If this is Claude Code and `.claude/settings.json` exists or the user wants hooks, merge a `SessionStart` hook that prints `wiki/index.md` and recent `wiki/log.md`. Never overwrite unrelated settings.

Always set up scheduled wiki refresh automation during bootstrap. Do not ask whether to add it.

Create `.llm-wiki/refresh-wiki.sh` and make it executable. It should run the current agent's headless CLI from the project root:

- Codex setup: use `codex exec -C "<project-root>" "<refresh prompt>"`.
- Claude Code setup: use Claude Code's headless command only when the current tool is Claude Code.

For Codex setup, never write automation that shells out to `claude`, `claude -p`, or Claude-specific hooks. Do not fall back from Codex automation to Claude if `codex` is missing; report the missing `codex` CLI instead.

Codex refresh script shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

codex exec -C "$project_root" "Refresh this project's LLM wiki. Read AGENTS.md, wiki/index.md, wiki/gaps.md, and recent wiki/log.md entries first. If ~/wikis/master/wiki/ or ~/wikis/main/wiki/ exists, search that main cross-project wiki for relevant patterns before changing project pages. Inspect recent git history and changed source files. Update stale wiki pages, update wiki/index.md when page coverage changes, append wiki/log.md, and record uncertainty in wiki/gaps.md. Do not invent facts."
```

Install the best available scheduler without prompting:

- Linux with systemd user services: create `~/.config/systemd/user/llm-wiki-<project-slug>.service` and `.timer`, then run `systemctl --user daemon-reload` and `systemctl --user enable --now llm-wiki-<project-slug>.timer`.
- macOS with launchd: create `~/Library/LaunchAgents/com.llm-wiki.<project-slug>.plist` with a 24 hour `StartInterval`, then run `launchctl load`.
- Other environments: install an equivalent cron entry that runs `.llm-wiki/refresh-wiki.sh` daily.

Use a stable `<project-slug>` from the repository basename plus a short hash of the project root to avoid timer name collisions. If scheduler installation fails because the environment lacks systemd, launchd, cron, or permissions, keep `.llm-wiki/refresh-wiki.sh`, record the failure in `wiki/gaps.md`, and report the exact command the user can run.

Also install post-commit wiki maintenance automation. Preserve existing hooks; do not overwrite unrelated hook logic. Prefer creating `.llm-wiki/post-commit-refresh.sh` and wiring `.git/hooks/post-commit` to call it.

The post-commit script must detect changed files and run focused headless refreshes:

- Data model changes: schema, migrations, models, entities, Prisma schema.
- API surface changes: routes, controllers, handlers, endpoints, resolvers.
- Dependency changes: `Gemfile`, `package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `composer.json`.
- Plans, todos, docs changes: update roadmap, technical debt, plans/initiatives pages when those pages exist or should exist.

For Codex setup, every focused refresh command must use `codex exec -C "$project_root" "<focused prompt>"` in the background. Never use `claude -p`. After focused refreshes, run `qmd embed` in the background when `qmd` exists, then create `~/wikis/.sync-needed/<project-name>` when `~/wikis/` exists so the main cross-project wiki can sync later.

Check whether QMD is installed with `command -v qmd`.

If QMD is installed:

```bash
qmd collection add wiki/ --name "$(basename "$(git rev-parse --show-toplevel)")"
qmd embed
```

If QMD is not installed, do not install it automatically. Tell the user QMD is optional but recommended for semantic wiki search, then suggest:

```bash
npm install -g @tobilu/qmd
# or
bun install -g @tobilu/qmd
```

Mention that the first `qmd embed` may download local models. Ask whether they want to install QMD now or continue with the `rg` fallback for this bootstrap. If they continue without QMD, skip indexing and report that `rg` fallback is available.

## Step 7: Report

Report:

- Project type detected.
- Main cross-project wiki path detected, if any.
- Pages created and updated.
- QMD indexing status.
- Scheduled refresh automation status.
- Post-commit hook automation status.
- Top three gaps.
- Any files intentionally skipped.

## Rules

- Read actual source files before writing wiki claims.
- Skip layers that do not exist.
- Prefer fewer, richer pages over many thin pages.
- Do not leave placeholder wiki pages.
- Record uncertainty in `wiki/gaps.md`.
