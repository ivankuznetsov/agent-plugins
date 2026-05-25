---
title: Interaction Surface
type: commands
source: README.md; plugins/llm-wiki/README.md; plugins/llm-wiki/skills/*/SKILL.md; plugins/screenote/README.md; plugins/screenote/codex-skills/*/SKILL.md; plugins/agent-seo/README.md; plugins/agent-seo/skills/seo/SKILL.md; plugins/agent-seo/commands/*.md; plugins/agent-seo/data_sources/ruby/bin/*
created: 2026-05-14
updated: 2026-05-25
tags: [commands, api]
---

**TLDR**: The external surface is marketplace installation plus plugin skills, Claude command files, Screenote MCP calls, optional Agent SEO Ruby CLIs, and the Agent Writing journalist/writer/editor commands.

## Marketplace Installation

The root `README.md` documents the marketplace entrypoints:

- Claude Code: `/plugin marketplace add ivankuznetsov/agent-plugins`, then `/plugin install <plugin>@aikuznetsov-marketplace`.
- Codex: `codex plugin marketplace add ivankuznetsov/agent-plugins`, then install through Codex's `/plugins` UI.

## LLM Wiki

`plugins/llm-wiki/README.md` and `plugins/llm-wiki/skills/*/SKILL.md` define four installed workflows:

| Skill | Purpose |
| --- | --- |
| `bootstrap` | Create or refresh a grounded project wiki, install agent context, and configure one headless maintenance owner. |
| `research` | Search project and main cross-project wiki context before planning or code changes. |
| `wiki-plan` | Run wiki research first, then plan through Compound Engineering when available or write a standalone plan. |
| `status` | Check local/marketplace `llm-wiki` versions and inspect wiki context plus automation ownership. |

The recent source names are `bootstrap`, `research`, `wiki-plan`, and `status`; git history shows the older `bootstrap-wiki`, `wiki-researcher`, and `wiki-plugin-status` skill names were renamed in commit `31e1037`.

The current README documents Claude Code invocations as `/llm-wiki:bootstrap`, `/llm-wiki:research`, `/llm-wiki:wiki-plan`, and `/llm-wiki:status`. For Codex, it documents `$llm-wiki:bootstrap`, `$llm-wiki:research`, `$llm-wiki:wiki-plan`, and `$llm-wiki:status`, with the caveat to use the fully qualified namespace if Codex displays one.

## Screenote

Screenote's Codex manifest points at `plugins/screenote/codex-skills/`; Claude has corresponding files under `plugins/screenote/skills/`.

| Skill | Surface |
| --- | --- |
| `screenote` | Captures one page at desktop/tablet/mobile by default, uploads a logical Screenote screenshot, and returns an annotation URL. |
| `feedback` | Reads open annotations, grouped by viewport when needed, and can comment plus resolve annotations after fixes. |
| `snapshot` | Discovers app routes, captures every page at one or three viewports, and titles snapshots with date plus git commit metadata. |

`plugins/screenote/.mcp.json` configures the `screenote` HTTP MCP server at `${SCREENOTE_URL:-https://screenote.ai}/mcp/messages`. The skills reference MCP operations such as `list_projects`, `create_multi_viewport_screenshot`, `list_pages`, `list_screenshots`, `list_annotations`, `get_annotation`, `add_annotation_comment`, and `resolve_annotation`.

## Agent SEO

Agent SEO exposes the same content workflow through different agent interfaces:

- Codex uses `plugins/agent-seo/skills/seo/SKILL.md` and natural-language prompts such as "Use Agent SEO to research ...".
- Claude Code uses command files in `plugins/agent-seo/commands/`, including `/seo:research`, `/seo:write`, `/seo:humanize`, `/seo:fact-check`, `/seo:optimize`, `/seo:rewrite`, `/seo:analyze-existing`, `/seo:scrub`, `/seo:data`, and `/seo:performance-review`.

The Agent SEO skill maps user intent to durable artifact folders: `research/`, `drafts/`, `rewrites/`, and `published/`. It also loads optional brand/content context from `plugins/agent-seo/context/`.

## Agent SEO Ruby CLIs

Optional Ruby tools live in `plugins/agent-seo/data_sources/ruby/bin/`:

- `seo-keywords`
- `seo-readability`
- `seo-quality`
- `seo-intent`
- `seo-scrub`

The README says these tools are optional; prompt-driven Agent SEO workflows continue without Ruby, Bundler, or data-source credentials.

## Agent Writing

Agent Writing exposes a three-voice team-of-rivals writing pipeline through both Claude Code commands and the Codex skill:

- Codex uses `plugins/agent-writing/skills/writing/SKILL.md` with natural-language prompts such as "Use Agent Writing to investigate ..." or "Use Agent Writing to run the writer-editor cycle on this draft".
- Claude Code uses command files in `plugins/agent-writing/commands/`:

| Command | Description |
| --- | --- |
| `/write:journalist <topic>` | Investigate a topic across the project's data; return a grounded brief at `investigations/<slug>-<date>.md`, or an honest "couldn't ground this" note when the evidence is thin. |
| `/write:writer <brief>` | Draft from a brief. With `--review <path>`, rewrite a previous draft against an editor's review (bumps the `-vN` suffix). |
| `/write:editor <draft>` | Read the draft as an adversary. Return cuts, questions, push-back, and a verdict: `ready`, `needs another pass`, or `start over`. |
| `/write:full <topic>` | Run the full pipeline: journalist gathers the brief, then the writer and editor enter a continuous cycle until verdict `ready` or `--max-rounds` (default 5). |

Agent Writing maps user intent to durable artifact folders inside the plugin: `investigations/`, `drafts/`, and `reviews/`. Drafts and reviews are versioned per round (`-v1.md`, `-v2.md`, …) so the conversation between writer and editor stays inspectable. Per-project voice loads from `plugins/agent-writing/context/` (`voice.md`, `style-guide.md`, `writing-examples.md`).

The team-of-rivals shape is the load-bearing design choice: the writer and editor share a model but are deliberately set up as adversaries — cooperation between a generator and its own critic produces flat writing, so the editor does not praise, does not rewrite for the writer, and does not soften its verdict. The cycle is external to both agents; the `write:full` orchestrator owns the loop.

Related: [[plugins]], [[dependencies]], [[architecture]].
