---
name: bootstrap
description: Bootstrap an LLM-maintained wiki for the current project. Use when a user asks to create, initialize, or refresh a project wiki, LLM wiki, QMD wiki, or codebase knowledge base for Claude Code, Codex, or Pi.
---

# Bootstrap LLM Wiki

Create a self-maintaining project wiki under `wiki/` for the current repository. Ground every page in actual source files and git history. Do not invent architecture, data models, routes, or decisions.

## Preconditions

- The current directory must be inside a git repository.
- QMD is optional but recommended. Use it when available; when missing, suggest installing it before falling back to `rg`.
- Merge existing agent settings and instructions. Do not overwrite existing config files blindly.
- Detect the main cross-project wiki when present. Check `~/wikis/master/wiki/`, `~/wikis/main/wiki/`, `<parent-of-project>/wikis/master/wiki/`, and `<parent-of-project>/wikis/main/wiki/`.
- Install wiki context for all supported agents. Only one agent owns headless scheduled and post-commit maintenance.

## Step 1: Detect Project Shape

Read the project root and identify:

- Language/framework: `Gemfile`, `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `composer.json`, `pom.xml`, `build.gradle`, `*.sln`, `*.csproj`, or equivalents.
- Persistence: schema files, migrations, ORM models, SQL files, or absence of a database.
- Entry points: routes, API specs, CLI commands, GraphQL schemas, gRPC protos, or main files.
- Architecture: services, domain modules, packages, jobs, queues, middleware, dependency injection, or monorepo boundaries.
- Tests, dependency files, CI/CD, Docker, and deploy config.
- Parent of project: `dirname "$(git rev-parse --show-toplevel)"`.
- Main cross-project wiki: whether any default path exists. Check in this order:
  - `~/wikis/master/wiki/`
  - `~/wikis/main/wiki/`
  - `<parent-of-project>/wikis/master/wiki/`
  - `<parent-of-project>/wikis/main/wiki/`
- If no main cross-project wiki exists, ask the user to either provide an existing main wiki folder or create a new master wiki at `<parent-of-project>/wikis/master/wiki/`. Wait for the user's answer before continuing.
- If creating a new main wiki, create the directory and seed `index.md`, `patterns.md`, `learnings.md`, and `log.md` with minimal grounded headings. Do not invent cross-project facts.

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

Before writing pages, search the detected or user-provided main cross-project wiki when it exists. Read relevant pages such as `patterns.md`, `learnings.md`, `decisions.md`, `architecture.md`, and `index.md` if present. Use this context to align project wiki structure and note reusable patterns, but only cite or summarize cross-project facts from pages actually read.

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

Create `.llm-wiki/` if it does not exist, then create or update `.llm-wiki/config.json`.

Config shape:

```json
{
  "headless_agent": "<claude-or-codex-or-pi>",
  "context_agents": ["claude", "codex", "pi"],
  "main_wiki_path": "<detected-or-provided-main-wiki-path>",
  "created_by": "<current-tool>"
}
```

Rules:

- `context_agents` is the supported context list and should include `claude`, `codex`, and `pi`.
- If `.llm-wiki/config.json` is missing, first check for legacy automation from older `llm-wiki` versions before treating this as a first bootstrap.
- Infer legacy ownership by searching `.llm-wiki/refresh-wiki.sh`, `.llm-wiki/post-commit-refresh.sh`, `.git/hooks/post-commit`, known `llm-wiki-<project-slug>` systemd or launchd scheduler files, and existing cron entries for `codex exec`, `claude -p`, `pi -p`, or `pi --print`.
- If exactly one legacy owner is found, preserve it as `headless_agent` and record it in `.llm-wiki/config.json`.
- If more than one owner command is found, or no owner can be inferred from existing automation, ask the user which agent should own headless maintenance before installing or rewriting automation.
- On true first bootstrap with no existing automation, set `headless_agent` to the current tool: `claude` for Claude Code, `codex` for Codex, or `pi` for Pi.
- On later bootstrap runs, preserve the existing `headless_agent` unless the user explicitly asks to switch it.
- If the current tool differs from `headless_agent`, still update wiki context for the current tool, but do not change scheduler or post-commit ownership.
- Scheduled refresh and post-commit refresh must use only `headless_agent`.
- Never run more than one headless maintenance agent for the same project by default.

Add a wiki section to all agents listed in `context_agents`:

- Claude Code: `CLAUDE.md`
- Codex: `AGENTS.md`
- Pi: `AGENTS.md`

Create files if absent. Append or replace only the managed wiki section between the markers below. Do not replace unrelated instructions or any unmarked user-authored `## Wiki` section.
When both Codex and Pi are listed, update `AGENTS.md` once; do not duplicate the managed wiki block.

Legacy migration:

- Older `llm-wiki` versions wrote an unmarked generated `## Wiki` section.
- If an unmarked `## Wiki` section clearly matches the generated `llm-wiki` template, wrap or replace it with the managed marker block below.
- Treat a section as generated only when it contains the project wiki bullet list, `wiki/index.md`, `wiki/log.md`, `wiki/gaps.md`, `raw/notes/`, and the QMD/`rg` query protocol.
- Preserve unmarked `## Wiki` sections that do not match the generated template, and add the managed block separately.

Instruction content:

```markdown
<!-- BEGIN LLM WIKI -->
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
1. Read `.llm-wiki/config.json` when it exists.
2. Run `qmd query "<topic>"` or `qmd search "<topic>"` when QMD is available.
3. Fall back to `rg "<topic>" wiki/`.
4. Check the configured `main_wiki_path` before making architectural decisions when it exists.
5. Also check default main cross-project wiki paths when they exist:
   - `~/wikis/master/wiki/`
   - `~/wikis/main/wiki/`
   - `<parent-of-project>/wikis/master/wiki/`
   - `<parent-of-project>/wikis/main/wiki/`
<!-- END LLM WIKI -->
```

## Step 6: Hooks, Scheduled Automation, and QMD

Install session context for supported agents separately from headless maintenance ownership.

Claude Code context:

- If `.claude/settings.json` exists, or it can be safely created, merge a `SessionStart` hook that prints `wiki/index.md` and recent `wiki/log.md`.
- Treat the Claude `SessionStart` hook as a context hook only. It does not mean Claude owns scheduled refresh.
- Never overwrite unrelated Claude settings.

Codex context:

- Ensure `AGENTS.md` contains the wiki section from Step 5.
- Codex currently receives repo context through `AGENTS.md`; do not invent a Codex hook system if one is not available.

Pi context:

- Ensure `AGENTS.md` contains the wiki section from Step 5.
- Pi loads project context from `AGENTS.md` and `CLAUDE.md`; treat `AGENTS.md` as the primary `llm-wiki` context surface for Pi.
- Do not create `.pi/SYSTEM.md` because it replaces Pi's default system prompt.
- Do not create `.pi/APPEND_SYSTEM.md` by default. Use `AGENTS.md` unless the user explicitly asks for Pi-specific system prompt customization.

Always ensure scheduled wiki refresh automation exists for the configured `headless_agent`. Do not ask whether to add it.

If the current tool is not the configured `headless_agent`, update session context for the current tool and validate/report the existing automation owner. Do not rewrite scheduler or post-commit ownership unless automation is missing, unsafe, or the user asks to repair or switch ownership.

The scheduler must use the configured `.llm-wiki/config.json` `headless_agent`.

Create `.llm-wiki/refresh-wiki.sh` and make it executable. It should run the configured headless agent's CLI from the project root:

- `headless_agent: "codex"`: use `codex exec -C "<project-root>" "<refresh prompt>"`.
- `headless_agent: "claude"`: use `claude -p "<refresh prompt>"` with the same refresh intent.
- `headless_agent: "pi"`: use `pi -p --no-session --tools read,bash,edit,write,grep,find,ls "<refresh prompt>"` with the same refresh intent.

For Codex-owned headless automation, never write automation that shells out to `claude` or `claude -p`. Do not fall back from Codex automation to Claude if `codex` is missing; report the missing `codex` CLI instead.

For Claude-owned headless automation, never write automation that shells out to `codex exec`. Do not fall back from Claude automation to Codex if `claude` is missing; report the missing `claude` CLI instead.

For Pi-owned headless automation, never write automation that shells out to `codex exec` or `claude -p`. Do not fall back from Pi automation to Claude or Codex if `pi` is missing; report the missing `pi` CLI instead.

Codex refresh script shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

codex exec -C "$project_root" "Refresh this project's LLM wiki. Read .llm-wiki/config.json, AGENTS.md, wiki/index.md, wiki/gaps.md, and recent wiki/log.md entries first. If .llm-wiki/config.json contains main_wiki_path, search that exact path before changing project pages. Also search default main cross-project wiki paths when they exist: ~/wikis/master/wiki/, ~/wikis/main/wiki/, ../wikis/master/wiki/, and ../wikis/main/wiki/. Inspect recent git history and changed source files. Update stale wiki pages, update wiki/index.md when page coverage changes, append wiki/log.md, and record uncertainty in wiki/gaps.md. Do not invent facts."
```

Claude Code refresh script shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

claude -p "Refresh this project's LLM wiki. Read .llm-wiki/config.json, CLAUDE.md, wiki/index.md, wiki/gaps.md, and recent wiki/log.md entries first. If .llm-wiki/config.json contains main_wiki_path, search that exact path before changing project pages. Also search default main cross-project wiki paths when they exist: ~/wikis/master/wiki/, ~/wikis/main/wiki/, ../wikis/master/wiki/, and ../wikis/main/wiki/. Inspect recent git history and changed source files. Update stale wiki pages, update wiki/index.md when page coverage changes, append wiki/log.md, and record uncertainty in wiki/gaps.md. Do not invent facts." --allowedTools "Bash,Read,Edit,Write" --max-budget-usd 0.50
```

Pi refresh script shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

pi -p --no-session --tools read,bash,edit,write,grep,find,ls "Refresh this project's LLM wiki. Read .llm-wiki/config.json, AGENTS.md, wiki/index.md, wiki/gaps.md, and recent wiki/log.md entries first. If .llm-wiki/config.json contains main_wiki_path, search that exact path before changing project pages. Also search default main cross-project wiki paths when they exist: ~/wikis/master/wiki/, ~/wikis/main/wiki/, ../wikis/master/wiki/, and ../wikis/main/wiki/. Inspect recent git history and changed source files. Update stale wiki pages, update wiki/index.md when page coverage changes, append wiki/log.md, and record uncertainty in wiki/gaps.md. Do not invent facts."
```

Install the best available scheduler without prompting:

- Linux with systemd user services: create `~/.config/systemd/user/llm-wiki-<project-slug>.service` and `.timer`, then run `systemctl --user daemon-reload` and `systemctl --user enable --now llm-wiki-<project-slug>.timer`.
- macOS with launchd: create `~/Library/LaunchAgents/com.llm-wiki.<project-slug>.plist` with a 24 hour `StartInterval`, then run `launchctl load`.
- Other environments: install an equivalent cron entry that runs `.llm-wiki/refresh-wiki.sh` daily.

Use a stable `<project-slug>` from the repository basename plus a short hash of the project root to avoid timer name collisions. Replace existing `llm-wiki-<project-slug>` scheduler files instead of adding duplicates. For cron, wrap the entry with `# BEGIN LLM WIKI <project-slug>` and `# END LLM WIKI <project-slug>` markers and replace that block on repeat bootstrap. If scheduler installation fails because the environment lacks systemd, launchd, cron, or permissions, keep `.llm-wiki/refresh-wiki.sh`, record the failure in `wiki/gaps.md`, and report the exact command the user can run.

Also install post-commit wiki maintenance automation. Preserve existing hooks; do not overwrite unrelated hook logic. Prefer creating `.llm-wiki/post-commit-refresh.sh` and wiring `.git/hooks/post-commit` to call it.

Post-commit hook idempotency:

- Add or replace only a managed `.git/hooks/post-commit` block marked `# BEGIN LLM WIKI POST-COMMIT` and `# END LLM WIKI POST-COMMIT`.
- Remove or replace older direct calls to `.llm-wiki/post-commit-refresh.sh` only when they are clearly attributable to `llm-wiki`.
- Never add a second managed post-commit block.
- `.llm-wiki/post-commit-refresh.sh` must acquire a project-local lock, such as `.llm-wiki/post-commit.lock`, before refreshing. If the lock already exists, exit without starting another refresh. Always release the lock on exit.
- `.llm-wiki/post-commit-refresh.sh` must sanitize Git hook-local environment variables before launching nested tools. Collect unset arguments from `git rev-parse --local-env-vars` and run `codex exec`, `claude -p`, `pi`, `qmd update`, and `qmd embed` through `env -u ...` so variables such as `GIT_INDEX_FILE`, `GIT_DIR`, and `GIT_WORK_TREE` cannot leak into agent startup, plugin marketplace checkouts, or QMD indexing. Keep local Git commands that inspect the triggering commit, such as `git diff-tree`, in the hook context.

The post-commit script must detect changed files and run focused headless refreshes:

- Data model changes: schema, migrations, models, entities, Prisma schema.
- API surface changes: routes, controllers, handlers, endpoints, resolvers.
- Dependency changes: `Gemfile`, `package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `composer.json`.
- Plans, todos, docs changes: update roadmap, technical debt, plans/initiatives pages when those pages exist or should exist.

For `headless_agent: "codex"`, every focused refresh command must use `codex exec -C "$project_root" "<focused prompt>"` in the background. Never use `claude -p`.

For `headless_agent: "claude"`, every focused refresh command must use `claude -p "<focused prompt>" --allowedTools "Bash,Read,Edit,Write" --max-budget-usd 0.50` in the background. Never use `codex exec`.

For `headless_agent: "pi"`, every focused refresh command must use `pi -p --no-session --tools read,bash,edit,write,grep,find,ls "<focused prompt>"` in the background. Never use `claude -p` or `codex exec`.

After focused refreshes, run `qmd embed` in the background when `qmd` exists, then create `<wikis-root>/.sync-needed/<project-name>` when the configured or detected main wiki root has a `.sync-needed` directory. Use the root containing `.llm-wiki/config.json` `main_wiki_path` first; otherwise use `~/wikis/.sync-needed/<project-name>` for home-based main wikis and `<parent-of-project>/wikis/.sync-needed/<project-name>` for parent-directory main wikis.

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
- Main cross-project wiki path detected, provided, or created.
- Context agents configured.
- Headless maintenance agent.
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
