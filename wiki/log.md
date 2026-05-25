# Wiki Changelog

Append-only log of meaningful wiki updates.

## [2026-05-14T16:53:28Z] bootstrap

**Action:** Managed llm-wiki bootstrap from codebase and Hive registry.
**Pages created:** wiki/active-areas.md, wiki/architecture.md, wiki/commands.md, wiki/decisions.md, wiki/dependencies.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Pages updated:** wiki/index.md, wiki/log.md, wiki/gaps.md, .llm-wiki/config.json, AGENTS.md, CLAUDE.md, .claude/settings.json
**QMD:** qmd missing
**Scheduler:** files written; systemctl enable failed for llm-wiki-agent-plugins-26fe9a15.timer
**Post-commit hook:** /home/asterio/Dev/agent-plugins/.git/hooks/post-commit
**Source:** Codebase read + git history

## [2026-05-14T17:07:25Z] refresh

**Action:** Refreshed project wiki from current config, main wiki search, git history, and vendored plugin source files.
**Pages created:** wiki/plugins.md, wiki/automation.md
**Pages updated:** wiki/architecture.md, wiki/commands.md, wiki/dependencies.md, wiki/decisions.md, wiki/active-areas.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched `/home/asterio/wikis/master/wiki`; default main paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki skills, Screenote skills/MCP config, Agent SEO skill/commands/Ruby data-source files, latest git commits
**QMD:** installed at `/usr/bin/qmd`; `qmd query` returned partial results but ended with `SQLITE_READONLY`, so direct `rg` searches grounded the refresh
**Gaps found:** scheduler activation unverified, QMD query/cache issue, unclear `pi` context agent, Agent SEO example content not audited
**Source:** Codebase read + git history + direct main-wiki search

## [2026-05-14T17:26:52Z] llm-wiki validation

**Action:** Validated managed llm-wiki bootstrap and scheduled maintenance after Hive registry bootstrap.
**Headless agent:** Codex (`.llm-wiki/config.json` has `headless_agent: "codex"`).
**Context:** `AGENTS.md` and `CLAUDE.md` contain the managed LLM WIKI block; Claude `SessionStart` prints `wiki/index.md` and recent `wiki/log.md`.
**QMD:** `qmd 2.1.0` collection update, embed, and `qmd search` succeeded for this collection after the scheduled refresh test. QMD attempted GPU first and fell back to CPU because Vulkan headers are missing.
**Scheduler:** `llm-wiki-agent-plugins-26fe9a15.timer` is enabled and active under `systemctl --user`; next run is scheduled for 2026-05-15 18:03:41 BST.
**Maintenance scripts:** `.llm-wiki/refresh-wiki.sh` and `.llm-wiki/post-commit-refresh.sh` use bounded Codex and qmd timeouts and tell headless Codex not to run `qmd update` or `qmd embed` itself.
**Source:** `systemctl --user list-timers`, `qmd update`, `qmd embed`, and collection-scoped `qmd search`.

## [2026-05-15T17:06:42Z] refresh

**Action:** Refreshed stale wiki automation, gaps, index, and active-area notes from current config, main wiki search, git history, source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/automation.md, wiki/gaps.md, wiki/index.md, wiki/active-areas.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, Screenote README/MCP config, Agent SEO README/skill, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`, while `qmd status` fell back to CPU because node-llama-cpp could not create a Vulkan lockfile under the read-only global npm install path.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd status/search without update/embed.

## [2026-05-16T17:06:24Z] refresh

**Action:** Refreshed wiki command, activity, automation, gaps, and index notes from current config, main wiki search, git history, changed source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/commands.md, wiki/active-areas.md, wiki/automation.md, wiki/dependencies.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`, while `qmd status` listed collections and then aborted with `vk::InitializationFailedError`.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; QMD GPU/model initialization remains environment-dependent; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd status/search without update/embed.

## [2026-05-17T17:06:52Z] refresh

**Action:** Refreshed activity, automation, gaps, and index notes from current config, main wiki search, git history, changed source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/active-areas.md, wiki/automation.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, Screenote README/MCP config, Agent SEO README/manifest, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`, while `qmd status` listed 360 indexed files and 2356 embedded vectors before aborting with `vk::InitializationFailedError`.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; QMD GPU/model initialization remains environment-dependent; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd status/search without update/embed.

## [2026-05-18T17:06:10Z] refresh

**Action:** Refreshed activity, automation, gaps, and index notes from current config, main wiki search, git history, changed source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/active-areas.md, wiki/automation.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, Screenote README/MCP config, Agent SEO README/manifest, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`, while `qmd status` listed 360 indexed files and 2492 embedded vectors before aborting with `vk::InitializationFailedError`.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; QMD GPU/model initialization remains environment-dependent; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd status/search without update/embed.

## [2026-05-19T17:06:38Z] refresh

**Action:** Refreshed activity, automation, gaps, and index notes from current config, main wiki search, git history, changed source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/active-areas.md, wiki/automation.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits, and the latest committed LLM Wiki source diffs.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`; `qmd status` was not rerun, so the 2026-05-18 `vk::InitializationFailedError` caveat remains the latest recorded status result.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; QMD GPU/model initialization remains environment-dependent; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.

## [2026-05-20T13:04:18Z] refresh

**Action:** Refreshed activity, automation, gaps, and index notes from current config, main wiki search, git history, changed source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/active-areas.md, wiki/automation.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits, and the latest committed LLM Wiki source diffs.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`; `qmd status` was not rerun, so the 2026-05-18 `vk::InitializationFailedError` caveat remains the latest recorded status result.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; QMD GPU/model initialization remains environment-dependent; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.

## [2026-05-21T16:13:44Z] refresh

**Action:** Refreshed activity, automation, gaps, and index notes from current config, main wiki search, git history, changed source files, and local automation state.
**Pages created:** none
**Pages updated:** wiki/active-areas.md, wiki/automation.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` and read index, conventions, patterns, learnings, and Screenote summary; default paths `/home/asterio/wikis/main/wiki`, `../wikis/master/wiki`, and `../wikis/main/wiki` were missing.
**Recent source inspected:** root README/catalogs, plugin manifests, LLM Wiki README/skills, Screenote README/MCP config, Agent SEO README/skill, current `.llm-wiki` scripts, Claude context, post-commit hook, systemd unit files, latest git commits, and the latest committed LLM Wiki source diffs.
**QMD:** did not run `qmd update` or `qmd embed`; `qmd search` succeeded for `agent-plugins`; `qmd status` was not rerun, so the 2026-05-18 `vk::InitializationFailedError` caveat remains the latest recorded status result.
**Gaps found:** current systemd timer activation cannot be checked from this sandbox; `pi` context remains unclear; QMD GPU/model initialization remains environment-dependent; Agent SEO example/vendor content remains unaudited.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.

## [2026-05-25T00:00:00Z] feature: agent-writing plugin shipped

**Action:** Implemented the `agent-writing` plugin from `docs/plans/2026-05-22-001-feat-agent-writing-plugin-plan.md` — a three-voice team-of-rivals writing pipeline (journalist + writer ↔ editor) with a continuous write-edit cycle.
**Pages created:** none
**Pages updated:** wiki/plugins.md, wiki/commands.md, wiki/log.md
**Plugin created:** `plugins/agent-writing/` (version `0.1.0`).
**Plugin files:** both manifests (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`), README, LICENSE, `skills/writing/SKILL.md`, three subagent files (`agents/journalist.md`, `agents/writer.md`, `agents/editor.md`), four slash commands (`commands/write:journalist.md`, `commands/write:writer.md`, `commands/write:editor.md`, `commands/write:full.md`), three context scaffolds (`context/voice.md`, `context/style-guide.md`, `context/writing-examples.md`), and three output folder `.gitkeep` files (`investigations/`, `drafts/`, `reviews/`).
**Marketplace catalogs updated:** appended an `agent-writing` entry to `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`.
**Design choice (load-bearing):** writer and editor are deliberately adversarial — cooperation between a generator and its own critic produces flat AI-shaped writing. The editor does not praise, does not rewrite for the writer, and does not soften its verdict (`ready` / `needs another pass` / `start over`). The write-edit cycle is external to both agents: the `write:full` orchestrator owns the loop, threading the prior round's review into the next round's writer invocation. Default cap: 5 rounds.
**Scope deferred to follow-up work:** (1) plugin-relative output folder pattern — review flagged that artifacts living inside the plugin directory will collide with plugin source for marketplace-installed users; v1 ships with plugin-relative folders matching `agent-seo` to keep the question reversible; (2) journalist source-citation verification — currently self-attested by the agent; (3) whether to share `context/` content with `agent-seo` rather than duplicating prose-craft guidance; (4) journalist's relationship to `llm-wiki:research` (overlap on project-investigation scope).
**Source:** `docs/plans/2026-05-22-001-feat-agent-writing-plugin-plan.md` (the deepened plan that drove this work).

## [2026-05-25T14:53:33Z] refresh

**Action:** Refreshed command/API surface coverage and adjacent architecture, decision, dependency, activity, index, and gap notes after commit `51dab1a` added Agent Writing.
**Pages created:** none
**Pages updated:** wiki/architecture.md, wiki/commands.md, wiki/decisions.md, wiki/dependencies.md, wiki/active-areas.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** searched configured `/home/asterio/wikis/master/wiki` for Agent Writing / `write:full` context; no matches were found.
**Recent source inspected:** `git show` for `51dab1a`, both marketplace catalogs, root `README.md`, `plugins/agent-writing` manifests, README, Codex skill, Claude `/write:*` command files, role subagents, context scaffolds, and existing wiki command/plugin pages.
**QMD:** did not run `qmd update` or `qmd embed`; a focused `qmd search "agent-writing write full command marketplace"` returned no project-local Agent Writing hit before wrapper maintenance, so source files and direct wiki reads grounded the refresh.
**Gaps found:** root README still omits Agent Writing from the plugin list/install examples/layout; Agent Writing artifact folder placement is unvalidated for marketplace-installed users; journalist source-citation verification is prompt-enforced rather than executable; relationship to `llm-wiki:research` remains undefined.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.

## [2026-05-25T14:58:41Z] refresh

**Action:** Refreshed planning and documentation coverage after commit `51dab1a` added a completed Agent Writing plan, plugin documentation, context scaffolds, and wiki changes.
**Pages created:** wiki/planning-docs.md
**Pages updated:** wiki/index.md, wiki/gaps.md, wiki/log.md
**Cross-project wiki:** checked configured `/home/asterio/wikis/master/wiki`; direct `rg` found no Agent Writing or `write:full` matches in the main wiki.
**Recent source inspected:** `AGENTS.md`, `.llm-wiki/config.json`, `git show` for `51dab1a`, `docs/plans/2026-05-22-001-feat-agent-writing-plugin-plan.md`, root `README.md`, both marketplace catalogs, Agent Writing manifests, README, commands, skill, role prompts, context scaffolds, and existing wiki pages.
**QMD:** did not run `qmd update` or `qmd embed`; focused `qmd search "agent-writing write full command marketplace"` returned a cross-collection `qmd://hive/log.md` result, so source files and direct wiki reads grounded the refresh.
**Gaps found:** QMD search scope can drift cross-collection; the completed plan still has unchecked implementation-unit boxes; Agent Writing context files are placeholder scaffolds; root README still omits Agent Writing.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.

## [2026-05-25T12:00:00Z] feature: agent-writing v1 open-question resolutions

**Action:** Resolved the four open questions deferred from the original agent-writing planning pass.
**Pages updated:** wiki/plugins.md, wiki/commands.md, wiki/log.md
**Resolutions:**
1. **Output location → host CWD.** Briefs, drafts, and reviews now write to the user's project working directory (`./writing/investigations/<slug>-<date>.md`, `./writing/drafts/<slug>-<date>-v<N>.md`, `./writing/reviews/<slug>-<date>-v<N>.md`), not inside the plugin. Plugin's own `investigations/`, `drafts/`, `reviews/` directories deleted. Users can add `/writing/` to their project's `.gitignore` if they don't want artifacts versioned.
2. **Journalist source-citation → deterministic verification.** Every citation in a brief is verified before the brief is final: `Read` for file paths, `git cat-file -e` for commit SHAs, HEAD for URLs. Failed citations get a verifiable replacement, get cut, or get flagged `[unverified]`. Brief frontmatter carries `verification: passed | partial`; brief body has a Verification section listing each citation's pass/fail.
3. **Build-vs-use vs. agent-seo → standalone.** No shared `context/` content with `agent-seo`. Duplication accepted.
4. **Journalist vs. llm-wiki:research → standalone.** No composition. The journalist does its own investigation.
**Files changed (plugin):** plugins/agent-writing/agents/{journalist,writer,editor}.md, plugins/agent-writing/commands/write:{journalist,writer,editor,full}.md, plugins/agent-writing/skills/writing/SKILL.md, plugins/agent-writing/README.md. Removed: plugins/agent-writing/{investigations,drafts,reviews}/.gitkeep and the empty directories.
**Plan updated:** docs/plans/2026-05-22-001-feat-agent-writing-plugin-plan.md — Resolved Open Questions section added; Output Structure and High-Level Technical Design diagrams updated to show host-CWD paths and the verification post-step.
**User direction on the standalone choices:** "no need for now to mix writing workflows with others."
**Source:** Codebase edits + user resolutions provided in conversation.

## [2026-05-25T15:25:53Z] refresh

**Action:** Refreshed command/API surface-adjacent wiki coverage after commit `9bb78ce` resolved Agent Writing open questions.
**Pages created:** none
**Pages updated:** wiki/architecture.md, wiki/decisions.md, wiki/dependencies.md, wiki/active-areas.md, wiki/planning-docs.md, wiki/gaps.md, wiki/index.md, wiki/log.md
**Cross-project wiki:** read `/home/asterio/wikis/master/wiki/index.md` and `patterns.md`; direct `rg` found no Agent Writing, `write:full`, host-CWD, or verification matches. Default paths `/home/asterio/wikis/main/wiki`, `/home/asterio/Dev/wikis/master/wiki`, and `/home/asterio/Dev/wikis/main/wiki` were missing.
**Recent source inspected:** `AGENTS.md`, `.llm-wiki/config.json`, `git show` and `git log` for `9bb78ce`, `README.md`, `docs/plans/2026-05-22-001-feat-agent-writing-plugin-plan.md`, Agent Writing README, Codex skill, Claude `/write:*` command files, role prompts, and current wiki command/plugin pages.
**QMD:** did not run `qmd update` or `qmd embed`; focused `qmd search "agent-writing host CWD verification standalone"` returned cross-collection Hive hits, so source files, direct wiki reads, and main-wiki `rg` grounded the refresh.
**Gaps found:** root README still omits Agent Writing; the completed Agent Writing plan still has historical plugin-relative path wording and unchecked implementation-unit boxes despite the newer resolution section; Agent Writing context scaffolds remain placeholders.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.

## [2026-05-25T15:31:38Z] refresh

**Action:** Refreshed planning and documentation coverage after commit `9bb78ce` touched the completed Agent Writing plan, plugin docs, command/agent prompt files, and wiki pages.
**Pages created:** none
**Pages updated:** wiki/planning-docs.md, wiki/index.md, wiki/gaps.md, wiki/log.md
**Cross-project wiki:** read `/home/asterio/wikis/master/wiki/index.md` and `patterns.md`; direct `rg` found no Agent Writing, `write:full`, host-CWD, source verification, or `./writing` matches.
**Recent source inspected:** `AGENTS.md`, `.llm-wiki/config.json`, `git show` for `9bb78ce`, `docs/plans/2026-05-22-001-feat-agent-writing-plugin-plan.md`, Agent Writing README, Codex skill, Claude `/write:*` command files, role prompts, context scaffolds, root `README.md`, and current wiki pages.
**QMD:** did not run `qmd update` or `qmd embed`; focused `qmd search "agent-writing planning docs context host CWD verification"` returned cross-collection Hive hits, so direct source reads grounded the refresh.
**Gaps found:** root README still omits Agent Writing; the completed Agent Writing plan keeps historical plugin-relative wording in early requirements, key decisions, implementation units, verification notes, and risk sections; Agent Writing context scaffolds remain placeholders.
**Source:** Codebase read + git history + direct main-wiki search + qmd search without update/embed.
