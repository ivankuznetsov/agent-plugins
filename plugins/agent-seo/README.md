# Agent SEO

Existing Claude Code installs that use `ivankuznetsov/claude-seo` remain supported. New installs should use the shared `ivankuznetsov/agent-plugins` marketplace.

Agent SEO is a Claude Code and Codex plugin for creating, analyzing, and optimizing SEO content. Use it to research topics, write long-form articles, humanize AI-assisted content, fact-check claims, analyze existing pages, and review performance data.

## Installation

### Claude Code

Add the shared marketplace and install Agent SEO:

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install agent-seo@aikuznetsov-marketplace
```

Existing legacy marketplace installs still work:

```text
/plugin marketplace add ivankuznetsov/claude-seo
/plugin install agent-seo@agent-seo
```

### Codex

Add the shared marketplace:

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open Codex, run `/plugins`, select `aikuznetsov-marketplace`, and install `agent-seo`.

Codex loads Agent SEO as a skill, not as native `/seo:*` slash commands. Ask for the skill by name:

```text
Use Agent SEO to research podcast monetization.
Use Agent SEO to write an article from research/brief-podcast-monetization-2026-04-29.md.
Use Agent SEO to audit drafts/podcast-monetization.md for SEO gaps and factual claims.
```

### Requirements

- Claude Code or Codex
- Ruby 3.0+ with Bundler, optional and only needed for local analysis tools

Core prompt-driven workflows work without Ruby: research, write, humanize, fact-check, optimize, rewrite, and analyze existing content.

## Claude Commands

Claude Code users can use these slash commands:

| Command | Description |
| --- | --- |
| `/seo:research [topic]` | Keyword research with web search |
| `/seo:write [topic]` | Write an SEO-optimized article |
| `/seo:humanize [file]` | Remove AI writing patterns |
| `/seo:fact-check [file]` | Verify claims using web search |
| `/seo:optimize [file]` | Final SEO optimization |
| `/seo:rewrite [topic]` | Update existing content |
| `/seo:analyze-existing [URL or file]` | Analyze content for improvements |
| `/seo:scrub [file]` | Remove AI watermarks |
| `/seo:data [type]` | Fetch GA4/GSC/DataForSEO/Ahrefs data |
| `/seo:performance-review [days]` | Review content performance |

## Codex Skill Workflows

Codex users should describe the workflow naturally:

- "Use Agent SEO to research [topic]"
- "Use Agent SEO to write from this research brief"
- "Use Agent SEO to humanize this draft"
- "Use Agent SEO to fact-check this article"
- "Use Agent SEO to optimize this file before publishing"
- "Use Agent SEO to fetch quick-win keyword data"

The installed `agent-seo` skill maps those requests to the same workflows as the Claude commands.

## Typical Workflow

```text
/seo:research cloud storage        # Claude command form
/seo:write cloud storage
/seo:humanize drafts/cloud-*.md
/seo:fact-check drafts/cloud-*.md
/seo:optimize drafts/cloud-*.md
```

In Codex, use the same sequence as natural language:

```text
Use Agent SEO to research cloud storage.
Use Agent SEO to write a draft from the cloud storage research brief.
Use Agent SEO to humanize, fact-check, and optimize the draft.
```

Each step builds on the previous one. Research saves a brief, writing loads it automatically when available, and review steps work on saved drafts.

## Optional Ruby Analysis Tools

Ruby tools live in `data_sources/ruby/bin/`:

```bash
seo-keywords --file article.md --keyword "podcast tips" --json
seo-readability --file article.md --json
seo-quality --file article.md --keyword "podcast tips" --json
seo-intent --keyword "how to start a podcast"
seo-scrub --file article.md --output cleaned.md --stats
```

Manual setup:

```bash
cd data_sources/ruby
bundle config set --local path vendor/bundle
bundle install
```

Claude Code runs `scripts/ensure-deps.sh` from its SessionStart hook when Ruby is available. Codex users should run the manual setup command only if they want the optional Ruby tools.

## Configuration

Customize files in `context/` for your brand:

| File | Purpose |
| --- | --- |
| `brand-voice.md` | Tone, messaging, vocabulary |
| `writing-examples.md` | Style reference articles |
| `style-guide.md` | Editorial standards |
| `seo-guidelines.md` | SEO requirements |
| `target-keywords.md` | Keyword priorities |
| `internal-links-map.md` | Internal linking targets |
| `features.md` | Product or service positioning |

Optional live data sources:

```bash
export GA4_PROPERTY_ID="your-property-id"
export GA4_CREDENTIALS_PATH="path/to/credentials.json"
export GSC_SITE_URL="https://yoursite.com"
export GSC_CREDENTIALS_PATH="path/to/credentials.json"
export DATAFORSEO_LOGIN="your-login"
export DATAFORSEO_PASSWORD="your-password"
export AHREFS_API_KEY="your-api-key"
```

## Project Structure

```text
agent-seo/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .codex-plugin/
│   └── plugin.json
├── skills/seo/SKILL.md
├── commands/
├── agents/
├── hooks/hooks.json
├── scripts/ensure-deps.sh
├── data_sources/ruby/
├── context/
├── drafts/
├── published/
├── rewrites/
└── research/
```

## Running Tests

```bash
cd data_sources/ruby
bundle exec ruby -Ilib:test test/*_test.rb
```

## License

MIT
