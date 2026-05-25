---
title: Plugins
type: architecture
source: README.md; .agents/plugins/marketplace.json; .claude-plugin/marketplace.json; plugins/*/.codex-plugin/plugin.json; plugins/*/.claude-plugin/plugin.json; plugins/*/README.md
created: 2026-05-14
updated: 2026-05-25
tags: [plugins, marketplace]
---

**TLDR**: The marketplace currently vendors four plugins: `llm-wiki`, `screenote`, `agent-seo`, and `agent-writing`.

## Catalog Summary

| Plugin | Version | Codex source | Claude source | Primary surface |
| --- | --- | --- | --- | --- |
| `llm-wiki` | `0.1.6` | `plugins/llm-wiki/.codex-plugin/plugin.json` | `plugins/llm-wiki/.claude-plugin/plugin.json` | Project wiki bootstrap, research, planning, and status skills. |
| `screenote` | `1.5.0` | `plugins/screenote/.codex-plugin/plugin.json` | `plugins/screenote/.claude-plugin/plugin.json` | Visual screenshot, snapshot, and feedback workflows backed by a Screenote MCP server. |
| `agent-seo` | `1.1.0` | `plugins/agent-seo/.codex-plugin/plugin.json` | `plugins/agent-seo/.claude-plugin/plugin.json` | SEO research, writing, humanization, fact-checking, optimization, data, and performance workflows. |
| `agent-writing` | `0.1.0` | `plugins/agent-writing/.codex-plugin/plugin.json` | `plugins/agent-writing/.claude-plugin/plugin.json` | Journalist + writer ↔ editor team-of-rivals writing pipeline with a continuous write-edit cycle. |

The Codex marketplace catalog points all four plugins at local paths under `./plugins/`. The Claude marketplace catalog records richer distribution metadata such as repository URL, license, keywords, category, and tags.

## LLM Wiki

Files:

- `plugins/llm-wiki/README.md`
- `plugins/llm-wiki/skills/bootstrap/SKILL.md`
- `plugins/llm-wiki/skills/research/SKILL.md`
- `plugins/llm-wiki/skills/wiki-plan/SKILL.md`
- `plugins/llm-wiki/skills/status/SKILL.md`

The Codex manifest advertises capabilities `Interactive`, `Read`, and `Write`, with default prompts for bootstrap, research, planning, and update status. The README says QMD is preferred but optional, with ripgrep fallback when QMD is unavailable.

## Screenote

Files:

- `plugins/screenote/codex-skills/screenote/SKILL.md`
- `plugins/screenote/codex-skills/feedback/SKILL.md`
- `plugins/screenote/codex-skills/snapshot/SKILL.md`
- `plugins/screenote/skills/screenote/SKILL.md`
- `plugins/screenote/skills/feedback/SKILL.md`
- `plugins/screenote/skills/snapshot/SKILL.md`
- `plugins/screenote/.mcp.json`

The Codex manifest points to `./codex-skills/` and declares `mcpServers: "./.mcp.json"`. The README describes Screenote as a visual feedback loop for AI coding agents, with page screenshots, app snapshots, and annotation retrieval.

## Agent SEO

Files:

- `plugins/agent-seo/skills/seo/SKILL.md`
- `plugins/agent-seo/commands/seo:*.md`
- `plugins/agent-seo/agents/*.md`
- `plugins/agent-seo/context/*.md`
- `plugins/agent-seo/data_sources/ruby/`
- `plugins/agent-seo/hooks/hooks.json`

Agent SEO's README states that core prompt-driven workflows work without Ruby. Optional Ruby tools provide local keyword density, readability, SEO quality, search-intent, content-scrubbing, and data-source analysis support.

## Agent Writing

Files:

- `plugins/agent-writing/skills/writing/SKILL.md`
- `plugins/agent-writing/commands/write:journalist.md`
- `plugins/agent-writing/commands/write:writer.md`
- `plugins/agent-writing/commands/write:editor.md`
- `plugins/agent-writing/commands/write:full.md`
- `plugins/agent-writing/agents/journalist.md`
- `plugins/agent-writing/agents/writer.md`
- `plugins/agent-writing/agents/editor.md`
- `plugins/agent-writing/context/*.md`

Agent Writing ships three writing voices working as a team of rivals: a journalist who investigates project data and files a grounded brief, a writer (the Generator — wants to produce, defends the draft), and an editor (the Adversary — wants the draft to be true, cuts what doesn't earn its place). The writer and editor run as a continuous write-edit cycle until the editor's verdict is `ready` or the configured maximum number of rounds is reached (default 5). The team-of-rivals shape is load-bearing: cooperation between a generator and its own critic produces flat AI-shaped writing, so the editor is deliberately adversarial — it does not praise, does not rewrite for the writer, and does not soften its verdict.

The cycle is external to both agents: the `write:full` orchestrator owns the loop. Neither the writer nor the editor invokes the other from inside their own reasoning. This separation preserves the rivalry.

Output folders: `investigations/` (journalist briefs), `drafts/` (writer drafts, versioned `-v1.md`, `-v2.md`, …), `reviews/` (editor reviews, paired with drafts). Per-project voice is configured via `context/voice.md`, `context/style-guide.md`, and `context/writing-examples.md`, which ship empty for install-site customization.

The `agent-writing:editor` is intentionally different from `agent-seo:editor` — the SEO plugin's editor humanizes content, while agent-writing's editor cuts and pushes back. The two live under separate plugin namespaces and do not interfere.

## Refresh Process

The root README says plugin refreshes should copy source repository contents into the matching `plugins/<name>` directory without nested `.git` metadata, then update both marketplace catalogs if plugin metadata changed. This follows the vendoring decision in [[decisions]].

Related: [[architecture]], [[commands]], [[dependencies]], [[active-areas]].
