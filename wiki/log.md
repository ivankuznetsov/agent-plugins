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
