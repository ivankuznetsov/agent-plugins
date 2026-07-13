# Quick Start

Agent SEO works in Claude Code and Codex. New installs should use the shared marketplace.

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
Use Agent SEO to humanize, fact-check, and optimize the draft.
```

Research briefs are saved in `research/`. Drafts are saved in `drafts/`.

## Optional Ruby Tools

Core workflows do not require Ruby. Install the optional local analysis tools only if you want keyword density, readability, SEO quality, search intent, and scrubber CLIs:

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

In Claude Code these map to `/seo:*` commands. In Codex, ask for Agent SEO by name and describe the workflow.

## More Detail

See `README.md` for installation, configuration, data source, and testing details.
