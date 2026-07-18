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

The canonical mode selectors are `research`, `write`, `humanize`, `fact-check`,
`optimize`, `analyze-existing`, `rewrite`, `scrub`, `data`, and
`performance-review`. Preserve the argument after the selector unchanged.

## Shared Ground Rules

- Use current web research for statistics, trends, competitor analysis, and factual claims.
- Prefer primary or authoritative sources for facts and cite source URLs in reports and drafts.
- Load available context files from `context/` before writing or optimizing: `brand-voice.md`, `writing-examples.md`, `style-guide.md`, `seo-guidelines.md`, `target-keywords.md`, `internal-links-map.md`, `features.md`, and `competitor-analysis.md`.
- Save durable artifacts to the existing workspace folders: `research/`, `drafts/`, `rewrites/`, and `published/`.
- Use lowercase hyphenated slugs and ISO dates in generated filenames.
- Ruby tools are optional. If Ruby, Bundler, or data source credentials are missing, continue with prompt-driven workflows and give setup guidance instead of failing.
- Resolve bundled `agents/`, `context/`, `data_sources/`, `hooks/`, and `scripts/`
  relative to the installed plugin root. Artifacts belong in the invocation
  working directory. Never depend on another checkout or a developer-specific
  absolute path.
- Some legacy prose names Python `data_sources/modules` files that are not
  shipped. Do not call them. Use the existing Ruby executables under
  `data_sources/ruby/bin/` and the configured Ruby integrations, or continue
  with clearly labeled partial data.

## Workflow Map

| User intent | Claude command equivalent | Output |
| --- | --- | --- |
| Research a topic | `/seo:research [topic]` | `research/brief-[topic-slug]-[YYYY-MM-DD].md` |
| Write an article | `/seo:write [topic or brief]` | `drafts/[topic-slug]-[YYYY-MM-DD].md` |
| Humanize content | `/seo:humanize [file or text]` | Updated content or rewritten response |
| Fact-check content | `/seo:fact-check [file or text]` | `drafts/seo:fact-check-[topic-slug]-[YYYY-MM-DD].md` |
| Optimize a draft | `/seo:optimize [file]` | `drafts/optimization-report-[topic-slug]-[YYYY-MM-DD].md` |
| Analyze existing content | `/seo:analyze-existing [URL or file]` | `research/analysis-[post-slug]-[YYYY-MM-DD].md` |
| Rewrite content | `/seo:rewrite [topic or analysis]` | `rewrites/[topic-slug]-rewrite-[YYYY-MM-DD].md` |
| Scrub AI watermarks | `/seo:scrub [file]` | Cleaned markdown file |
| Fetch SEO data | `/seo:data [type]` | Data-backed recommendations |
| Review performance | `/seo:performance-review [days]` | `research/seo:performance-review-[YYYY-MM-DD].md` |

## Research Workflow

Use this when the user asks for topic research, keyword research, competitor analysis, or content planning.

1. Search the current landscape:
   - `[topic] 2026`, `[topic] statistics`, `[topic] trends`, `best [topic]`
   - `[topic] questions`, `how to [topic]`, `[topic] problems`
   - `[topic] research study`, `[topic] industry report`, `[topic] expert opinion`
2. Identify the primary keyword, secondary keywords, long-tail variations, related questions, and search intent.
3. Run the intent-analysis pass and classify search intent as informational, navigational, transactional, or commercial investigation, with confidence and content format recommendation.
4. Compare the top 10 SERP results for common sections, word count, content gaps, featured snippet opportunities, and unique angles.
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
8. Run the Scrub Workflow on the saved Markdown before review (the bundled
   Ruby `seo-scrub` is preferred; apply the same rules directly when it is not
   available).
9. Dispatch the five established post-write agents: `content-analyzer`,
   `seo-optimizer`, `meta-creator`, `internal-linker`, and `keyword-mapper`.
   Preserve their distinct reports: content analysis, SEO recommendations,
   metadata options, internal-link opportunities, and keyword mapping. Missing
   optional Ruby/data inputs produce partial reports, not a failed article.

## Humanize Workflow

Use this when the user asks to make AI-assisted content sound natural.

1. Read the file or supplied text.
2. Run the established 24-pattern audit: inflated significance, notability
   claims, superficial `-ing` analysis, promotional language, vague
   attribution, formulaic sections, overused AI vocabulary, copula avoidance,
   negative parallelisms, rule-of-three padding, elegant-variation synonyms,
   fake quotations, excessive headings, sentence fragments, repetitive
   conclusions, generic transitions, canned reader address, needless
   restatement, hedging, throat-clearing, chatbot artifacts, decorative
   styling, em-dash overuse, and generic conclusions.
3. Replace em dashes and decorative styling when they read as AI artifacts.
4. Preserve meaning, facts, source citations, brand voice, and the target audience.
5. Add specificity, varied rhythm, concrete examples, and practical judgments where the draft is generic.
6. Return the revised content. If a file path was provided and the user expects an edit, update that file.

## Fact-Check Workflow

Use this when the user asks to verify a draft or specific claims.

1. Run a separate extraction pass for factual claims: statistics, dates,
   company/product claims, technical assertions, rankings, comparisons, and
   quotes. Do not let verification bias which claims get extracted.
2. Prioritize high-impact claims first.
3. In a separate verification pass, search primary or authoritative sources;
   use recent sources for fast-changing topics and seek 2-3 independent sources
   for important claims.
4. Mark each claim as `VERIFIED`, `NEEDS UPDATE`, `UNVERIFIABLE`, or `LIKELY FALSE`.
5. Suggest exact corrections and cite the best source URL.
6. Apply accepted corrections to the checked content, preserving meaning and
   citations; do not stop after producing recommendations.
7. Save the compatibility report to
   `drafts/seo:fact-check-[topic-slug]-[YYYY-MM-DD].md` when checking a file.

## Optimization Workflow

Use this for final SEO review before publishing.

1. Audit keyword density, placement, semantic variations, and stuffing risk.
2. Check heading hierarchy, word count, paragraph length, sentence length, readability, active voice, and scannability.
3. Validate internal links against `context/internal-links-map.md` and check external links for authority and freshness.
4. Review meta title length, meta description length, URL slug, featured snippet opportunities, image alt text needs, and schema suggestions.
5. Assess brand alignment, introduction strength, value delivery, conclusion, and CTA.
6. Dispatch `content-analyzer`, `seo-optimizer`, `meta-creator`,
   `internal-linker`, and `keyword-mapper` on the complete draft. Score the
   result out of 100 as four explicit 25-point categories: content quality,
   keyword optimization, technical/on-page SEO, and links/authority. Produce
   priority fixes, quick wins, strategic improvements, meta options, link
   recommendations, keyword distribution, final checklist, and publishing
   readiness.
7. Save to `drafts/optimization-report-[topic-slug]-[YYYY-MM-DD].md`.

## Analyze Existing Workflow

Use this when the user gives a URL or existing file for audit.

1. Fetch or read the content, including headings and structure.
2. Identify publication age, freshness issues, target keyword, search intent, keyword placement, content gaps, readability problems, and metadata issues.
3. Run `content-analyzer` metrics and compare current coverage with the top
   10-20 SERP competitors, including their length/word-count benchmark,
   structure, gaps, and freshness where evidence is available.
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
7. Run the Scrub Workflow, then dispatch `content-analyzer`, `seo-optimizer`,
   `meta-creator`, and `internal-linker` as the established four-agent rewrite
   review wave. Keep partial-data labels when optional inputs are unavailable.

## Scrub Workflow

Use this only on an existing Markdown file. Refuse a missing path, directory,
non-Markdown input, symlinked destination, or unexpected overwrite target.

1. Read the file, retain its permissions, and work through a private temporary
   output before atomically replacing that same file.
2. Remove every Unicode category `Cf` format-control character, including the
   documented zero-width space/non-joiner, BOM, word joiner, soft hyphen, and
   narrow no-break space cases.
3. Replace em dashes contextually with a comma, colon, semicolon, parentheses,
   or sentence break; do not perform a blind one-character substitution.
4. Report counts by removed/replaced kind plus a 300-character verification
   sample without inventing content.
5. A second run must be idempotent: zero additional removals or replacements.

## Data Workflow

Use this when the user asks for live performance data, priority queues, opportunities, quick wins, declining content, page analysis, backlink data, authority, or competitors.

Supported types:

- `priority [limit]` (default 10)
- `opportunities [days]` (default 30)
- `quick-wins [days]` (default 30)
- `declining [days]` (default 30)
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
3. Dispatch the bundled `performance` agent and score opportunities as **50%
   impact**, **30% effort**, and **20% confidence**. Keep those weights stable
   across hosts.
4. Produce an executive summary, priority queue, detailed analysis, implementation roadmap, and success metrics.
5. Save to `research/seo:performance-review-[YYYY-MM-DD].md`.

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
