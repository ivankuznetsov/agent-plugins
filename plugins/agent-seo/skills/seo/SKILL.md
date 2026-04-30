---
name: agent-seo
description: Complete SEO content workflow for Codex and Claude Code. Use when the user asks for Agent SEO, agent-seo, SEO topic research, SEO article writing, content humanization, fact-checking, content optimization, existing-page analysis, content rewriting, AI watermark scrubbing, live SEO data, or performance review. In Codex, users invoke this skill by asking for Agent SEO or describing the SEO workflow they want; in Claude Code, the same workflows are also exposed as /seo:* commands.
---

# Agent SEO

Agent SEO creates, analyzes, and optimizes long-form SEO content. Codex uses this skill as the native entry point. Claude Code users can keep using the `/seo:*` command files.

## Invocation

In Codex, respond to natural requests such as:

```text
Use Agent SEO to research podcast monetization.
Use Agent SEO to write an article from research/brief-podcast-monetization-2026-04-29.md.
Use Agent SEO to check drafts/podcast-monetization.md for SEO gaps and factual claims.
```

Do not promise Codex-native `/seo:*` slash commands. Those command names are the Claude Code interface. When a Codex user mentions `/seo:research`, `/seo:write`, or another `/seo:*` command, run the equivalent workflow from this skill.

## Shared Ground Rules

- Use current web research for statistics, trends, competitor analysis, and factual claims.
- Prefer primary or authoritative sources for facts and cite source URLs in reports and drafts.
- Load available context files from `context/` before writing or optimizing: `brand-voice.md`, `writing-examples.md`, `style-guide.md`, `seo-guidelines.md`, `target-keywords.md`, `internal-links-map.md`, `features.md`, and `competitor-analysis.md`.
- Save durable artifacts to the existing workspace folders: `research/`, `drafts/`, `rewrites/`, and `published/`.
- Use lowercase hyphenated slugs and ISO dates in generated filenames.
- Ruby tools are optional. If Ruby, Bundler, or data source credentials are missing, continue with prompt-driven workflows and give setup guidance instead of failing.

## Workflow Map

| User intent | Claude command equivalent | Output |
| --- | --- | --- |
| Research a topic | `/seo:research [topic]` | `research/brief-[topic-slug]-[YYYY-MM-DD].md` |
| Write an article | `/seo:write [topic or brief]` | `drafts/[topic-slug]-[YYYY-MM-DD].md` |
| Humanize content | `/seo:humanize [file or text]` | Updated content or rewritten response |
| Fact-check content | `/seo:fact-check [file or text]` | `drafts/fact-check-[topic-slug]-[YYYY-MM-DD].md` |
| Optimize a draft | `/seo:optimize [file]` | `drafts/optimization-report-[topic-slug]-[YYYY-MM-DD].md` |
| Analyze existing content | `/seo:analyze-existing [URL or file]` | `research/analysis-[post-slug]-[YYYY-MM-DD].md` |
| Rewrite content | `/seo:rewrite [topic or analysis]` | `rewrites/[topic-slug]-rewrite-[YYYY-MM-DD].md` |
| Scrub AI watermarks | `/seo:scrub [file]` | Cleaned markdown file |
| Fetch SEO data | `/seo:data [type]` | Data-backed recommendations |
| Review performance | `/seo:performance-review [days]` | `research/performance-review-[YYYY-MM-DD].md` |

## Research Workflow

Use this when the user asks for topic research, keyword research, competitor analysis, or content planning.

1. Search the current landscape:
   - `[topic] 2026`, `[topic] statistics`, `[topic] trends`, `best [topic]`
   - `[topic] questions`, `how to [topic]`, `[topic] problems`
   - `[topic] research study`, `[topic] industry report`, `[topic] expert opinion`
2. Identify the primary keyword, secondary keywords, long-tail variations, related questions, and search intent.
3. Classify search intent as informational, navigational, transactional, or commercial investigation, with confidence and content format recommendation.
4. Review top-ranking competitor content for common sections, word count, content gaps, featured snippet opportunities, and unique angles.
5. Cross-check context files for brand voice, product positioning, internal links, target keywords, and SEO requirements.
6. Produce a research brief with SEO foundation, competitive landscape, recommended outline, statistics to include, source URLs, internal linking strategy, meta preview, and next steps.
7. Save to `research/brief-[topic-slug]-[YYYY-MM-DD].md`.

## Writing Workflow

Use this when the user asks to create a new long-form article.

1. Read the relevant research brief if available.
2. Load brand voice, writing examples, style guide, SEO guidelines, target keywords, internal links, and product features from `context/`.
3. Search for current statistics, examples, best practices, authoritative sources, and competitor gaps before drafting.
4. Write a complete 2000-3000+ word markdown article with:
   - H1 containing the primary keyword naturally
   - 150-200 word introduction with hook, problem, promise, and keyword in the first 100 words
   - 4-7 H2 sections with useful H3 subsections
   - 3-5 internal links and 2-3 authoritative external links
   - practical examples, data, and clear takeaways
   - conclusion with a relevant CTA
5. Include frontmatter or a metadata block with meta title, meta description, primary keyword, secondary keywords, URL slug, links, and word count.
6. Add an SEO checklist covering keyword placement, links, metadata lengths, word count, hierarchy, readability, and CTA.
7. Save to `drafts/[topic-slug]-[YYYY-MM-DD].md`.
8. If Ruby tools are available, run `data_sources/ruby/bin/seo-scrub` on the draft and optionally run keyword, readability, and quality analysis. If unavailable, note that analysis tools can be installed later.

## Humanize Workflow

Use this when the user asks to make AI-assisted content sound natural.

1. Read the file or supplied text.
2. Remove inflated significance language, overused AI vocabulary, vague attribution, formulaic sections, excessive hedging, chatbot artifacts, and generic conclusions.
3. Replace em dashes and decorative styling when they read as AI artifacts.
4. Preserve meaning, facts, source citations, brand voice, and the target audience.
5. Add specificity, varied rhythm, concrete examples, and practical judgments where the draft is generic.
6. Return the revised content. If a file path was provided and the user expects an edit, update that file.

## Fact-Check Workflow

Use this when the user asks to verify a draft or specific claims.

1. Extract factual claims: statistics, dates, company/product claims, technical assertions, rankings, comparisons, and quotes.
2. Prioritize high-impact claims first.
3. Search for primary or authoritative sources; use recent sources for fast-changing topics.
4. Mark each claim as `VERIFIED`, `NEEDS UPDATE`, `UNVERIFIABLE`, or `LIKELY FALSE`.
5. Suggest exact corrections and cite the best source URL.
6. Save a fact-check report to `drafts/fact-check-[topic-slug]-[YYYY-MM-DD].md` when checking a file.

## Optimization Workflow

Use this for final SEO review before publishing.

1. Audit keyword density, placement, semantic variations, and stuffing risk.
2. Check heading hierarchy, word count, paragraph length, sentence length, readability, active voice, and scannability.
3. Validate internal links against `context/internal-links-map.md` and check external links for authority and freshness.
4. Review meta title length, meta description length, URL slug, featured snippet opportunities, image alt text needs, and schema suggestions.
5. Assess brand alignment, introduction strength, value delivery, conclusion, and CTA.
6. Produce an SEO score out of 100, priority fixes, quick wins, strategic improvements, meta options, link recommendations, keyword distribution, final checklist, and publishing readiness.
7. Save to `drafts/optimization-report-[topic-slug]-[YYYY-MM-DD].md`.

## Analyze Existing Workflow

Use this when the user gives a URL or existing file for audit.

1. Fetch or read the content, including headings and structure.
2. Identify publication age, freshness issues, target keyword, search intent, keyword placement, content gaps, readability problems, and metadata issues.
3. Compare current coverage with SERP competitors and note word count benchmarks where possible.
4. Produce a content health score, quick wins, strategic improvements, detailed analysis, rewrite recommendation, and an initial research brief if a rewrite is needed.
5. Save to `research/analysis-[post-slug]-[YYYY-MM-DD].md`.

## Rewrite Workflow

Use this when the user asks to refresh or improve existing content.

1. Read the original content and any analysis report.
2. Choose rewrite scope: light update, moderate refresh, major rewrite, or complete overhaul.
3. Keep still-accurate sections and unique insights; update outdated statistics, examples, terminology, metadata, and links.
4. Add sections that fill competitor gaps and remove duplicate or outdated material.
5. Preserve ranking-sensitive URL slug unless the user asks otherwise.
6. Save the rewritten article to `rewrites/[topic-slug]-rewrite-[YYYY-MM-DD].md` and a change summary to `rewrites/changes-[topic-slug]-[YYYY-MM-DD].md`.
7. Scrub and analyze with Ruby tools when available.

## Data Workflow

Use this when the user asks for live performance data, priority queues, opportunities, quick wins, declining content, page analysis, backlink data, authority, or competitors.

Supported types:

- `priority [limit]`
- `opportunities [days]`
- `quick-wins [days]`
- `declining [days]`
- `page [url]`
- `backlinks [domain]`
- `authority [domain]`
- `competitors [domain]`

Before running Ruby data calls, check configuration:

- `GA4_PROPERTY_ID` and `GA4_CREDENTIALS_PATH`
- `GSC_SITE_URL` and `GSC_CREDENTIALS_PATH`
- `DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD`
- `AHREFS_API_KEY`

If no data sources are configured, respond with setup guidance and explain what each source provides. Do not attempt a Ruby call that is guaranteed to fail. If some sources are configured, return partial results and clearly label missing sources.

## Performance Review Workflow

Use this for periodic content portfolio analysis.

1. Collect available GA4, GSC, DataForSEO, and Ahrefs data.
2. Identify quick wins, declining content, low-CTR opportunities, trending topics, and competitor gaps.
3. Score opportunities by impact, effort, and confidence.
4. Produce an executive summary, priority queue, detailed analysis, implementation roadmap, and success metrics.
5. Save to `research/performance-review-[YYYY-MM-DD].md`.

## Ruby Analysis Tools

Optional tools live in `data_sources/ruby/bin/`:

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

Claude Code may run `scripts/ensure-deps.sh` from its SessionStart hook. Codex users should run the manual setup command only if they want the optional Ruby analysis tools.

## Quality Targets

- Primary keyword density: 1-2%, placed in H1, first 100 words, 2-3 H2s, meta title, and meta description.
- Article length: 2000+ words, with 2500-3000+ preferred for competitive long-form topics.
- Internal links: 3-5 relevant links with descriptive anchor text.
- External links: 2-3 authoritative sources for claims and data.
- Meta title: 50-60 characters.
- Meta description: 150-160 characters.
- Readability: 8th-10th grade, short paragraphs, varied sentence rhythm.
- Humanization: no filler, chatbot artifacts, inflated AI vocabulary, or unsupported claims.
