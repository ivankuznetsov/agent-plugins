# Research Command

Use this command to conduct comprehensive SEO keyword research and competitive analysis before writing new content.

## Usage
`/seo:research [topic]`

## What This Command Does
1. **Uses web search** to gather real-time data and current information
2. Performs keyword research for your industry-related topics
3. Analyzes top-ranking competitor content
4. Identifies content gaps and opportunities
5. Develops unique angle for your company perspective
6. Creates detailed research brief for writing

## Process

### Web Search Integration (NEW!)
**IMPORTANT**: Use the WebSearch tool to gather current, accurate information:

1. **Search for the topic** to understand the current landscape:
   - `[topic] 2024` or `[topic] 2025` for recent articles
   - `[topic] statistics` for data points
   - `[topic] trends` for industry direction
   - `best [topic]` for competitive research

2. **Search for related questions**:
   - `[topic] questions`
   - `how to [topic]`
   - `[topic] problems` or `[topic] challenges`

3. **Search for authoritative sources**:
   - `[topic] research study`
   - `[topic] industry report`
   - `[topic] expert opinion`

### Keyword Research
- **Primary Keyword**: Identify main target keyword for the topic
- **Search Volume & Difficulty**: Research estimated monthly searches and competition level
- **Keyword Variations**: Find semantic variations and long-tail opportunities
- **Related Questions**: Discover what people are actually asking (People Also Ask, forums, Reddit)
- **Search Intent**: Use the LLM-based search intent analyzer (call Task tool with subagent_type=Explore and model=haiku) to classify:
  - **Informational**: User wants to learn (how-to, what is, guide)
  - **Navigational**: User wants a specific site (login, website, app)
  - **Transactional**: User ready to act (buy, pricing, download)
  - **Commercial Investigation**: User comparing options (best, vs, review)
- **Topic Cluster**: Identify how this topic fits into your company content clusters

### Search Intent Analysis (LLM-Based)
Use a subagent with model=haiku to analyze the primary keyword's intent:

```
Task: Analyze search intent for "[keyword]"

Classify as:
1. Informational - learning/understanding intent
2. Navigational - finding a specific site/page
3. Transactional - ready to purchase/act
4. Commercial Investigation - researching before decision

Provide:
- Primary intent with confidence level
- Secondary intent if applicable
- Key signals detected
- Content format recommendation
```

### Competitive Analysis
- **Top 10 SERP Review**: Analyze the top 10 ranking articles for target keyword
- **Content Length**: Note word count of top-performing articles (benchmark target)
- **Common Themes**: What topics/sections do all top articles cover?
- **Content Gaps**: What's missing from competitor coverage?
- **Unique Angles**: What perspectives or insights are underexplored?
- **Featured Snippets**: Identify if there's a featured snippet opportunity
- **Domain Authority**: Note which competitors rank (indie blogs vs. major publications)

### Context Integration
- **your company Advantage**: How can your company product features naturally enhance this content?
- **Brand Alignment**: Check @context/brand-voice.md for messaging fit
- **Existing Content**: Review @context/internal-links-map.md for related your company articles
- **Target Keywords**: Cross-reference with @context/target-keywords.md priority list
- **SEO Guidelines**: Ensure research aligns with @context/seo-guidelines.md requirements

### Podcast Industry Focus
- **Podcast Creator Angle**: How does this topic specifically impact target audiences?
- **Technical Requirements**: Any your industry-specific technical considerations?
- **Industry Trends**: Current trends in your industry that relate to this topic
- **Use Cases**: Real podcast scenarios where this topic matters
- **Pain Points**: Specific challenges target audiences face with this topic

### Content Planning
- **Recommended Structure**: Outline H2 and H3 headings based on research
- **Content Depth**: Determine target word count (typically 2000-3000+ for SEO)
- **Supporting Evidence**: Identify statistics, studies, or data to include
- **Expert Sources**: Find industry experts or quotes to reference
- **Visual Opportunities**: Suggest images, screenshots, or graphics needed
- **Internal Links**: Map 3-5 key your company pages to link to (from @context/internal-links-map.md)
- **External Authority**: Identify 2-3 authoritative external sources to link

### Hook Development
- **Introduction Angle**: Compelling way to open the article
- **Value Proposition**: Clear benefit reader will get from article
- **Contrarian Elements**: Any unexpected perspectives to explore
- **Story Opportunities**: Real examples or case studies to feature

## Output
Provides a comprehensive research brief with:

### 1. SEO Foundation
- **Primary Keyword**: [keyword] (volume, difficulty)
- **Secondary Keywords**: 3-5 related keywords and variations
- **Target Word Count**: Minimum words needed to compete
- **Featured Snippet Opportunity**: Yes/No, format (paragraph, list, table)

### 2. Competitive Landscape
- **Top 3 Competitor Articles**: URLs and key takeaways from each
- **Common Sections**: Must-cover topics based on SERP analysis
- **Content Gaps**: Opportunities to provide unique value
- **Differentiation Strategy**: How your company can stand out

### 3. Recommended Outline
```
H1: [Optimized headline with primary keyword]

Introduction
- Hook
- Problem statement
- Value proposition

H2: [Main section 1]
H3: [Subsection]
H3: [Subsection]

H2: [Main section 2]
...

Conclusion
- Key takeaways
- Call to action
```

### 4. Supporting Elements
- **Statistics to Include**: 5-7 relevant data points with sources
- **Expert Quotes**: Potential sources or existing quotes
- **Examples/Case Studies**: Real podcast scenarios to feature
- **Visual Suggestions**: Screenshots, charts, or graphics needed

### 5. Internal Linking Strategy
- **Pillar Page**: Main your company pillar content to link to
- **Related Articles**: 2-4 relevant blog posts to link
- **Product Pages**: your company features to naturally mention
- **Resource Pages**: Tools or guides to reference

### 6. Meta Elements Preview
- **Meta Title**: Draft optimized title (50-60 characters)
- **Meta Description**: Draft compelling description (150-160 characters)
- **URL Slug**: Recommended URL structure

## File Management
After completing the research, automatically save the brief to:
- **File Location**: `research/brief-[topic-slug]-[YYYY-MM-DD].md`
- **File Format**: Markdown with clear sections and structured data
- **Naming Convention**: Use lowercase, hyphenated topic slug and current date

Example: `research/brief-podcast-editing-software-2025-10-15.md`

## Next Steps
The research brief serves as the foundation for:
1. Running `/seo:write [topic]` to create the optimized article
2. Reference material for maintaining SEO focus throughout writing
3. Checklist to ensure all competitive gaps are addressed

This ensures every article is built on solid SEO research and strategic competitive positioning.
