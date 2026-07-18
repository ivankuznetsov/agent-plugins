---
name: bootstrap
description: Bootstrap an LLM-maintained wiki for the current project. Use when a user asks to create, initialize, or refresh a project wiki, LLM wiki, QMD wiki, or codebase knowledge base for Claude Code, Codex, Pi, or OpenClaw.
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
- `wiki/log.d/`: directory of append-only `<timestamp>-<slug>.md` changelog fragments (one file per change — conflict-free across branches/worktrees).
- `wiki/log.md`: the COMPILED changelog, regenerated from `wiki/log.d/*.md` by `.llm-wiki/compile-log.sh`. Seed it with the header plus an empty generated block so the compiler is idempotent:

  ```
  # Wiki Changelog

  Append-only log of all wiki operations.

  <!-- BEGIN GENERATED WIKI LOG FRAGMENTS -->
  <!-- END GENERATED WIKI LOG FRAGMENTS -->
  ```

  Never hand-edit the content between the markers. On an EXISTING project whose `log.md` predates fragments, leave the old hand-written `## ` entries in place below the markers — `compile-log.sh` preserves them as legacy and prepends compiled fragments above, so migration is lossless.
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

Write the bootstrap changelog entry as a fragment `wiki/log.d/<timestamp>-bootstrap.md` (then run `.llm-wiki/compile-log.sh .` to regenerate `wiki/log.md`):

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
  "headless_agent": "<claude-or-codex-or-pi-or-openclaw>",
  "context_agents": ["claude", "codex", "pi", "openclaw"],
  "openclaw_agent_id": "<configured-agent-id-or-null>",
  "main_wiki_path": "<detected-or-provided-main-wiki-path>",
  "created_by": "<current-tool>"
}
```

Rules:

- `headless_agent` must be exactly one of `claude`, `codex`, `pi`, or `openclaw`. Reject any other value instead of silently falling back to a different agent.
- `context_agents` is the supported context list and should include `claude`, `codex`, `pi`, and `openclaw`.
- When OpenClaw is the headless owner, run `openclaw agents list --json`, select the single agent whose `workspace` resolves to the project root, and persist its `id` as `openclaw_agent_id`. Do not guess `main`; agent IDs and the default agent can be customized.
- When OpenClaw is not the headless owner, preserve an existing `openclaw_agent_id` or write `null` when no matching project-workspace agent is known.
- If `.llm-wiki/config.json` is missing, first check for legacy automation from older `llm-wiki` versions before treating this as a first bootstrap.
- Infer legacy ownership by searching `.llm-wiki/refresh-wiki.sh`, `.llm-wiki/post-commit-refresh.sh`, `.git/hooks/post-commit`, known `llm-wiki-<project-slug>` systemd or launchd scheduler files, and existing cron entries for `codex exec`, `claude -p`, `pi -p`, `pi --print`, or `openclaw agent --local`.
- If exactly one legacy owner is found, preserve it as `headless_agent` and record it in `.llm-wiki/config.json`.
- If more than one owner command is found, or no owner can be inferred from existing automation, ask the user which agent should own headless maintenance before installing or rewriting automation.
- On true first bootstrap with no existing automation, set `headless_agent` to the current tool: `claude` for Claude Code, `codex` for Codex, `pi` for Pi, or `openclaw` for OpenClaw.
- On later bootstrap runs, preserve the existing `headless_agent` unless the user explicitly asks to switch it.
- If the current tool differs from `headless_agent`, still update wiki context for the current tool, but do not change scheduler or post-commit ownership.
- Scheduled refresh and post-commit refresh must use only `headless_agent`.
- Never run more than one headless maintenance agent for the same project by default.

Add a wiki section to all agents listed in `context_agents`:

- Claude Code: `CLAUDE.md`
- Codex: `AGENTS.md`
- Pi: `AGENTS.md`
- OpenClaw: `AGENTS.md` in the configured OpenClaw agent workspace

Create files if absent. Append or replace only the managed wiki section between the markers below. Do not replace unrelated instructions or any unmarked user-authored `## Wiki` section.
When any of Codex, Pi, and OpenClaw share the same project workspace, update `AGENTS.md` once; do not duplicate the managed wiki block.

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
- `wiki/log.md` — compiled changelog (regenerated from `wiki/log.d/*.md` fragments; never hand-edited)
- `wiki/gaps.md` — known gaps and open questions
- `raw/notes/` — manually added reference material

Always check `wiki/` before answering questions about this project's architecture, patterns, or decisions.

When you learn something new about the project or make a decision:
1. Create or update the relevant page in `wiki/`
2. Update `wiki/index.md` if a new page was created
3. Add a `wiki/log.d/<timestamp>-<slug>.md` fragment (never hand-edit the compiled `wiki/log.md`; it is regenerated from fragments by `.llm-wiki/compile-log.sh`)

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

OpenClaw context:

- Ensure `AGENTS.md` contains the wiki section from Step 5. OpenClaw auto-injects the `AGENTS.md` in its configured agent workspace at the start of every session.
- Confirm the project root is the active OpenClaw agent workspace before selecting `openclaw` as `headless_agent`. If it is not, report the workspace mismatch instead of claiming the project `AGENTS.md` will be injected.
- Do not add channel-delivery flags to wiki maintenance commands. Scheduled and post-commit refreshes are local automation, not chat replies.

Always ensure scheduled wiki refresh automation exists for the configured `headless_agent`. Do not ask whether to add it.

If the current tool is not the configured `headless_agent`, update session context for the current tool and validate/report the existing automation owner. Do not rewrite scheduler or post-commit ownership unless automation is missing, unsafe, or the user asks to repair or switch ownership.

The scheduler must use the configured `.llm-wiki/config.json` `headless_agent`.

Create `.llm-wiki/refresh-wiki.sh` and make it executable. It should run the configured headless agent's CLI from the project root:

- `headless_agent: "codex"`: use `codex exec -C "<project-root>" "<refresh prompt>"`.
- `headless_agent: "claude"`: use `claude -p "<refresh prompt>"` with the same refresh intent.
- `headless_agent: "pi"`: use `pi -p --no-session --tools read,bash,edit,write,grep,find,ls "<refresh prompt>"` with the same refresh intent.
- `headless_agent: "openclaw"`: use `openclaw agent --local --agent "<openclaw_agent_id>" --message "<refresh prompt>" --json --timeout 1800` from the configured OpenClaw project workspace. The explicit agent selector is required by the CLI and binds the turn to the verified project workspace. Omit `--deliver`, `--channel`, `--reply-channel`, `--reply-to`, and `--to` so automation cannot send the result to a channel.

For Codex-owned headless automation, never write automation that shells out to `claude` or `claude -p`. Do not fall back from Codex automation to Claude if `codex` is missing; report the missing `codex` CLI instead.

For Claude-owned headless automation, never write automation that shells out to `codex exec`. Do not fall back from Claude automation to Codex if `claude` is missing; report the missing `claude` CLI instead.

For Pi-owned headless automation, never write automation that shells out to `codex exec` or `claude -p`. Do not fall back from Pi automation to Claude or Codex if `pi` is missing; report the missing `pi` CLI instead.

For OpenClaw-owned headless automation, never write automation that shells out to `codex exec`, `claude -p`, or `pi`. Do not fall back from OpenClaw automation to another agent if `openclaw` is missing; report the missing `openclaw` CLI or project-workspace mismatch instead.

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

OpenClaw refresh script shape:

```bash
#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

openclaw agent --local --agent "<openclaw_agent_id>" --message "Refresh this project's LLM wiki. Read .llm-wiki/config.json, AGENTS.md, wiki/index.md, wiki/gaps.md, and recent wiki/log.md entries first. If .llm-wiki/config.json contains main_wiki_path, search that exact path before changing project pages. Also search default main cross-project wiki paths when they exist: ~/wikis/master/wiki/, ~/wikis/main/wiki/, ../wikis/master/wiki/, and ../wikis/main/wiki/. Inspect recent git history and changed source files. Update stale wiki pages, update wiki/index.md when page coverage changes, add a wiki/log.d/<timestamp>-<slug>.md fragment without editing compiled wiki/log.md, and record uncertainty in wiki/gaps.md. Do not invent facts." --json --timeout 1800
```

Install the best available scheduler without prompting:

- Linux with systemd user services: create `~/.config/systemd/user/llm-wiki-<project-slug>.service` and `.timer`, then run `systemctl --user daemon-reload` and `systemctl --user enable --now llm-wiki-<project-slug>.timer`.
- macOS with launchd: create `~/Library/LaunchAgents/com.llm-wiki.<project-slug>.plist` with a 24 hour `StartInterval`, then run `launchctl load`.
- Other environments: install an equivalent cron entry that runs `.llm-wiki/refresh-wiki.sh` daily.

Use a stable `<project-slug>` from the repository basename plus a short hash of the project root to avoid timer name collisions. Replace existing `llm-wiki-<project-slug>` scheduler files instead of adding duplicates. For cron, wrap the entry with `# BEGIN LLM WIKI <project-slug>` and `# END LLM WIKI <project-slug>` markers and replace that block on repeat bootstrap. If scheduler installation fails because the environment lacks systemd, launchd, cron, or permissions, keep `.llm-wiki/refresh-wiki.sh`, record the failure in `wiki/gaps.md`, and report the exact command the user can run.

Also install post-commit wiki maintenance automation. Preserve existing hooks; do not overwrite unrelated hook logic. Install the canonical runtime in the shared Git directory and wire the common `post-commit` hook to pass the committing worktree explicitly.

Install `.llm-wiki/post-commit-refresh.sh` AND `.llm-wiki/compile-log.sh` by copying the reference scripts bundled with this skill at `templates/post-commit-refresh.sh` and `templates/compile-log.sh` (resolve them relative to this SKILL.md), then `chmod +x` both. Also copy the same files verbatim to `$(git rev-parse --git-common-dir)/llm-wiki/post-commit-refresh.sh` and `compile-log.sh`, and copy the validated project config there as `config.json`. The hook must invoke that shared runner as `post-commit-refresh.sh --project "$(git rev-parse --show-toplevel)"`, falling back to the checkout-local runner only when the shared copy is absent. This makes one bootstrap or upgrade authoritative for every linked worktree, including older branches with stale ignored `.llm-wiki` files or config. `compile-log.sh` is the single source of truth for the changelog format: it regenerates `wiki/log.md` from the append-only `wiki/log.d/*.md` fragments, and the refresh runs it before committing. (Hive's `Hive::WikiLog` delegates here, so Ruby and shell callers share one implementation.) The bundled post-commit script reads the canonical shared `headless_agent` and dispatches to exactly one provider; never customize its provider function per project. Provider, QMD, and Git ref execution requires `timeout` or `gtimeout` so every potentially stuck command is bounded. When neither is available, the worker must fail before starting a provider. A repository-wide circuit stops automatic provider launches after two consecutive failed batches or when more than 25 sources are pending by default. A worker handles at most one batch of 10 sources with bounded path context; sources arriving outside that snapshot open a `deferred:<count>` circuit. New sources continue queueing until an operator explicitly runs `.llm-wiki/post-commit-refresh.sh --retry-failed <sha|all>` once per bounded batch.
The supported provider set is Claude Code, Codex, Pi, and OpenClaw. The copied
config must preserve `openclaw_agent_id` when OpenClaw owns maintenance; the
runtime rejects an unsupported owner or a missing/invalid OpenClaw agent ID
instead of falling back to another provider.

Transactional refresh contract (the bundled script implements all of these; any hand-edit must keep them):

- **User checkouts are read-only inputs.** Queue each relevant source SHA under `$(git rev-parse --git-common-dir)/llm-wiki/pending/` before attempting the worker lock. Never use the committing checkout or first/main checkout as an agent workspace, log destination, QMD cache, staging area, or commit target.
- **Use one managed refresh branch and disposable worktree.** Drain queued commits on local branch `llm-wiki/refresh` in `<shared-git-dir>/llm-wiki/refresh-worktree`, based/rebased on the current default branch. The agent inspects source commits with `git show`; it writes only under the managed worktree's `wiki/`.
- **Seed ignored local wikis once.** When a new refresh branch has no tracked `wiki/`, copy the committing checkout's untracked local wiki into the disposable worktree before invoking the agent. Never replace an already-established refresh-branch wiki, follow a top-level `wiki` symlink, or copy any path outside `wiki/`.
- **Serialize and coalesce.** Hold one stale-reclaimable compare-and-swap lock at `refs/llm-wiki/refresh-lock`. Its Git blob records PID, time, process-start identity, and nonce; `git update-ref <ref> <new> <old>` makes stale replacement single-winner, while ownership-checked deletion prevents an old worker from releasing a successor's lock. Check the wait deadline and sleep after every failed acquisition attempt. One worker snapshots at most 10 queued SHAs and runs one refresh agent for that batch. A busy worker leaves new queue entries intact for a later worker instead of dropping them.
- **Receipt completed sources.** Add one exact `LLM-Wiki-Source: <sha>` commit-message paragraph when the batch creates a wiki commit, then atomically update `refs/llm-wiki/receipts/<sha>` for every successful source before queue deletion. Check receipt refs first and commit history as migration fallback before invoking the agent. This makes both changed and no-op batches replay-safe after a crash between completion and acknowledgement.
- **Pin queued commits.** Create `refs/llm-wiki/sources/<sha>` when a source is queued and delete it in the same ref transaction that writes its durable receipt. Backfill pins for pre-upgrade pending and quarantined records. Refuse to invoke or acknowledge a batch whose selected SHA is not an available commit.
- **Recover stale locks safely.** A live owner PID with the recorded process-start identity wins. Dead, PID-reused, or malformed owner blobs are replaceable only through the Git ref's compare-and-swap old-OID guard.
- **Validate before committing.** Reject any tracked, untracked, or ignored change outside `wiki/`. Compile `wiki/log.md`, force-stage only `wiki/` so intentionally ignored wikis persist, and commit with both recursion guards (`HIVE_SKIP_LLM_WIKI_POST_COMMIT=1` and `git -c core.hooksPath=/dev/null`). Never push automatically.
- **Failure is clean and bounded.** If agent execution, wiki-only validation, compilation, staging, or commit fails, force-remove the disposable managed worktree. After two consecutive failed batches by default, move the active batch to `<shared-git-dir>/llm-wiki/failed/` and open the repository-wide circuit. Continue queueing new sources without launching a provider. Never delete failed source data or automatically run a quarantined source again. User checkout bytes and branch refs must remain unchanged.
- **Subscription use is bounded.** Run provider overrides, Codex, Claude Code,
  Pi, QMD, and Git ref operations through `timeout` or `gtimeout`. If no bounded
  runner is available, fail closed before starting a provider and retain the
  queue. Open the circuit before a provider launch when pending sources exceed
  25; cap every batch at 10 sources and bound the changed-path prompt context.
  The circuit can be retried only through `.llm-wiki/post-commit-refresh.sh
  --retry-failed <sha|all>`; process one bounded batch per invocation and clear
  it only when no queued or quarantined sources remain.
- **Keep generated state outside worktrees.** Refresh logs, pending entries, locks, and fallback QMD cache live under `<shared-git-dir>/llm-wiki/`.

Post-commit hook idempotency:

- Add or replace only a managed `.git/hooks/post-commit` block marked `# BEGIN LLM WIKI POST-COMMIT` and `# END LLM WIKI POST-COMMIT`. The block honors `HIVE_SKIP_LLM_WIKI_POST_COMMIT` so the script's own wiki commit cannot recurse.
- Remove or replace older direct calls to `.llm-wiki/post-commit-refresh.sh` only when they are clearly attributable to `llm-wiki`.
- Never add a second managed post-commit block.
- `.llm-wiki/post-commit-refresh.sh` must sanitize Git hook-local environment variables before launching nested tools. Collect unset arguments from `git rev-parse --local-env-vars` and run `codex exec`, `claude -p`, `pi`, `openclaw agent`, `qmd update`, and `qmd embed` through `env -u ...` so variables such as `GIT_INDEX_FILE`, `GIT_DIR`, and `GIT_WORK_TREE` cannot leak into agent startup, plugin marketplace checkouts, or QMD indexing. Keep local Git commands that inspect the triggering commit, such as `git diff-tree`, in the hook context.

The post-commit script detects relevant changed files and coalesces them into one focused headless refresh per queued batch:

- Data model changes: schema, migrations, models, entities, Prisma schema.
- API surface changes: routes, controllers, handlers, endpoints, resolvers.
- Dependency changes: `Gemfile`, `package.json`, `go.mod`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `composer.json`.
- Plans, todos, docs changes: update roadmap, technical debt, plans/initiatives pages when those pages exist or should exist.
- Common source, test, template, and config trees: refresh affected behavior and
  architecture coverage for `app/`, `src/`, `lib/`, `test/`, `tests/`, `spec/`,
  `templates/`, and `config/` changes.

For `headless_agent: "codex"`, the runtime dispatcher must use `codex exec -C "$refresh_root" "$prompt"` and never use `claude -p`, `pi -p`, or `openclaw agent`.

For `headless_agent: "claude"`, the runtime dispatcher must use `claude -p "$prompt" --allowedTools "Bash,Read,Edit,Write" --add-dir "$refresh_root" --max-budget-usd 0.50` from the managed worktree and never use `codex exec`, `pi -p`, or `openclaw agent`.

For `headless_agent: "pi"`, the runtime dispatcher must use `pi -p --no-session --tools read,bash,edit,write,grep,find,ls "$prompt"` from the managed worktree and never use `claude -p`, `codex exec`, or `openclaw agent`.

For `headless_agent: "openclaw"`, the runtime dispatcher must use `openclaw agent --local --agent "<openclaw_agent_id>" --message "$prompt" --json --timeout 1800` from the managed worktree without any delivery, channel, reply, or recipient flag. Never use `claude -p`, `codex exec`, or `pi`.

After a queued batch succeeds, run bounded `qmd update` and `qmd embed` from the managed refresh worktree with their cache outside user checkouts, then create `<wikis-root>/.sync-needed/<project-name>` when a supported sync directory exists. Failed batches retain their queue and do not index discarded work.

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
