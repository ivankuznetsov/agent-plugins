# Next Steps

Use this checklist after installing Agent SEO.

## Configure Your Content Context

Start with these files:

1. `context/brand-voice.md`
   - Define voice pillars, terminology, tone, and messaging rules.
2. `context/writing-examples.md`
   - Add 3-5 strong articles that represent the style you want.
3. `context/internal-links-map.md`
   - List important product, feature, blog, resource, and conversion pages.

Then refine:

- `context/target-keywords.md` for priority keyword clusters.
- `context/style-guide.md` for editorial rules.
- `context/features.md` for product or service positioning.
- `context/competitor-analysis.md` for competitor notes.
- `context/seo-guidelines.md` for SEO requirements.

## Test One Article

Claude Code:

```text
/seo:research a topic relevant to your business
/seo:write a topic relevant to your business
/seo:humanize drafts/topic-*.md
/seo:fact-check drafts/topic-*.md
/seo:optimize drafts/topic-*.md
```

Codex:

```text
Use Agent SEO to research a topic relevant to my business.
Use Agent SEO to write an article from the research brief.
Use Agent SEO to humanize, fact-check, and optimize the draft.
```

Review the research brief in `research/` and the article in `drafts/`.

## Optional Data Sources

Configure live performance data only if you need `/seo:data` or performance review workflows:

- GA4 for traffic and engagement metrics.
- Google Search Console for rankings, impressions, CTR, and quick wins.
- DataForSEO for SERP and keyword metrics.
- Ahrefs for authority, backlinks, and competitor data.

If these are not configured, Agent SEO should provide setup guidance instead of failing the workflow.

## Optional Ruby Analysis

Install the local Ruby tools if you want CLI keyword density, readability, SEO quality, search intent, and scrubber checks:

```bash
cd data_sources/ruby
bundle config set --local path vendor/bundle
bundle install
```

Core prompt-driven workflows work without Ruby.

## Recommended Publishing Flow

1. Research the topic.
2. Write the draft.
3. Humanize the prose.
4. Fact-check claims and statistics.
5. Optimize metadata, links, headings, readability, and keyword placement.
6. Move final content to `published/` or your CMS.
7. Use data workflows later to find refresh and quick-win opportunities.

## Release Maintenance

For plugin maintainers:

- Keep `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions in sync.
- Keep the legacy `.claude-plugin/marketplace.json` install path working.
- Update `ivankuznetsov/agent-plugins` after Agent SEO releases so shared marketplace users receive the current submodule SHA.
- Validate JSON manifests and run Ruby tests before release when dependencies are available.
