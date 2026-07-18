# Quick Start

Agent SEO works in Claude Code, Codex, Pi, and OpenClaw. New Claude/Codex
installs use the shared marketplace; OpenClaw installs use ClawHub.

## 1. Install

Claude Code:

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install agent-seo@aikuznetsov-marketplace
```

Codex:

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open Codex, run `/plugins`, select `aikuznetsov-marketplace`, and install `agent-seo`.

Existing Claude Code users with `ivankuznetsov/claude-seo` can keep that marketplace installed.

Pi from a clone:

```bash
pi install /path/to/agent-plugins/plugins/agent-seo
```

OpenClaw from ClawHub:

```bash
openclaw plugins install clawhub:agent-seo
```

## 2. Configure Context

Fill in the files that shape the output:

1. `context/brand-voice.md` - voice, tone, vocabulary, positioning.
2. `context/features.md` - product or service features and differentiators.
3. `context/writing-examples.md` - 3-5 strong articles for style reference.

Optional but useful:

- `context/internal-links-map.md` for key pages and preferred anchors.
- `context/target-keywords.md` for keyword clusters.
- `context/style-guide.md` for editorial preferences.

## 3. Run Your First Workflow

Claude Code:

```text
/seo:research your topic
/seo:write your topic
/seo:humanize drafts/your-topic-*.md
/seo:fact-check drafts/your-topic-*.md
/seo:optimize drafts/your-topic-*.md
```

Codex:

```text
Use Agent SEO to research your topic.
Use Agent SEO to write an article from the research brief.
Use Agent SEO to humanize the draft for clarity and brand voice, then fact-check and optimize it.
```

Pi and OpenClaw use the same named-skill form:

```text
Use Agent SEO to audit drafts/your-topic.md for formatting controls.
```

Research briefs are saved in `research/`. Drafts are saved in `drafts/`.

## Optional Ruby Tools

Core workflows do not require Ruby. Install the optional local analysis tools only if you want keyword density, readability, SEO quality, search intent, and the read-only formatting audit CLI:

```bash
cd data_sources/ruby
bundle config set --local path vendor/bundle
bundle install
```

## Common Workflows

```text
Research a topic
Write from a research brief
Analyze an existing URL or local article
Rewrite outdated content
Run a final optimization pass
Fetch quick-win keyword data
```

In Claude Code these map to `/seo:*` commands. In Codex, Pi, and OpenClaw, ask
for Agent SEO by name and describe the workflow.

Agent SEO writes new project-local artifacts by default. It edits an existing
file only when you explicitly ask it to modify that exact path, and it preserves
authorship, provenance, and AI-use disclosures.

## More Detail

See `README.md` for installation, configuration, data source, and testing details.
