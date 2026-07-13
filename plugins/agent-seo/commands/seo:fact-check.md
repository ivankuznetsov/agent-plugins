# Fact-Check Command

Use this command to verify claims, statistics, and factual statements in content using web search and LLM-powered analysis.

## Usage
`/seo:fact-check [file path or paste text]`

## What This Command Does
1. Uses **Haiku 4.5** subagent for fast claim extraction
2. Verifies claims with web search
3. Confirms or flags potentially incorrect information
4. Suggests corrections with proper source citations
5. Ensures content meets accuracy standards

## LLM-Powered Fact Checking

**IMPORTANT**: Use a Haiku 4.5 subagent for efficient claim extraction and verification:

```
Task tool with model=haiku:

1. Extract all factual claims from the content:
   - Statistics and numbers
   - Dates and historical facts
   - Company/product claims
   - Expert quotes
   - Comparative statements

2. For each claim, assess:
   - Verifiability (can this be checked?)
   - Risk level (high/medium/low impact if wrong)
   - Search query to verify

3. Return structured list of claims to verify
```

Then use WebSearch to verify each claim, and use another Haiku subagent to:
- Compare search results against claims
- Determine verification status
- Suggest corrections if needed

## Process

### 1. Extract Claims to Verify (Haiku 4.5)
Use a subagent to scan the content for:

#### Statistics & Numbers
- Percentages (e.g., "80% of podcasters...")
- Dollar amounts (e.g., "The industry is worth $4 billion...")
- Growth rates (e.g., "growing 25% year over year...")
- User/audience counts (e.g., "500 million podcast listeners...")
- Time-based claims (e.g., "Most podcasts last 30-45 minutes...")

#### Factual Assertions
- Historical claims (e.g., "Podcasting started in 2004...")
- Company/product facts (e.g., "Spotify acquired Anchor in 2019...")
- Industry standards (e.g., "The standard sample rate is 44.1kHz...")
- Technical specifications (e.g., "MP3 files should be 128kbps...")
- Legal/regulatory claims (e.g., "GDPR requires consent for...")

#### Comparative Claims
- "Best" or "most popular" assertions
- Market share statements
- Rankings or lists
- Comparisons between products/services

#### Expert Quotes & Attributions
- Verify the quote is accurate
- Confirm the person's credentials
- Check the quote isn't taken out of context

### 2. Search for Verification

For each claim, use WebSearch to find:
- **Primary sources** (original research, official reports)
- **Authoritative secondary sources** (industry publications, reputable news)
- **Multiple confirming sources** (at least 2-3 independent sources for key claims)

#### Search Strategies
- `"[exact statistic]"` - Search for the exact number in quotes
- `[topic] statistics [year]` - Find recent data
- `[company] announcement [fact]` - Verify company-related claims
- `[study/report name] [key finding]` - Find original research
- `[expert name] [quote excerpt]` - Verify quotes

### 2.5 Verify with Haiku 4.5

After gathering search results, use a Haiku subagent to analyze:

```
Task tool with model=haiku:

Given:
- Claim: "[the claim from the content]"
- Search results: [summary of what was found]

Determine:
1. Verification status: VERIFIED / NEEDS UPDATE / UNVERIFIABLE / LIKELY FALSE
2. If incorrect, what is the accurate information?
3. Best source to cite
4. Suggested correction text (if needed)
```

This provides fast, cost-effective verification of each claim.

### 3. Evaluate Sources

Rate each source on:
- **Authority**: Is this a credible source? (government, academic, industry leader)
- **Recency**: How old is this information?
- **Primary vs Secondary**: Is this the original source or citing another?
- **Bias**: Does the source have a vested interest?

#### Trustworthy Sources (Prefer These)
- Government agencies (e.g., FCC, BLS)
- Academic institutions and peer-reviewed research
- Industry associations (e.g., IAB, Edison Research)
- Established news organizations
- Company official statements (for company-specific facts)

#### Less Reliable Sources (Use Cautiously)
- Blog posts without citations
- Social media posts
- Wikipedia (use as starting point, not final source)
- Marketing materials
- Old articles (>2 years for fast-changing topics)

### 4. Generate Fact-Check Report

#### Report Format

```markdown
# Fact-Check Report

**Content**: [File name or content identifier]
**Checked**: [Date]
**Claims Reviewed**: [Number]

## Summary
- Verified: [X] claims
- Needs Update: [X] claims
- Could Not Verify: [X] claims
- Potentially False: [X] claims

## Verified Claims
These claims are accurate based on authoritative sources:

### Claim 1: "[Claim text]"
- Status: VERIFIED
- Source: [Source name and URL]
- Notes: [Any relevant context]

## Claims Needing Updates
These claims have newer or more accurate information available:

### Claim 1: "[Claim text]"
- Status: NEEDS UPDATE
- Issue: [What's wrong or outdated]
- Correction: [Accurate information]
- Source: [Source for correction]
- Suggested edit: "[Revised text]"

## Unverifiable Claims
Could not find reliable sources to confirm or deny:

### Claim 1: "[Claim text]"
- Status: UNVERIFIABLE
- Searches attempted: [What was searched]
- Recommendation: [Remove, rephrase, or add qualifier]

## Potentially False Claims
These claims appear to be inaccurate:

### Claim 1: "[Claim text]"
- Status: LIKELY FALSE
- Evidence: [Why this appears false]
- Accurate information: [What's actually true]
- Source: [Source for correct information]
- Required action: MUST CORRECT

## Recommendations
1. [Specific action items]
2. [Sources to add]
3. [Sections to update]
```

### 5. Common Issues to Watch For

#### Outdated Statistics
- Industry statistics change rapidly
- Check publication dates of cited sources
- Search for more recent data

#### Misattributed Quotes
- Quotes spread on social media are often misattributed
- Verify with original source when possible

#### Exaggerated Claims
- "Everyone uses X" - Quantify instead
- "The best" - Add criteria or qualifier
- "Always" / "Never" - Usually overstated

#### Confusion Between Correlation and Causation
- "X causes Y" - Verify causal relationship
- Look for the actual study methodology

#### Company Claims
- Marketing claims may be exaggerated
- Verify with independent sources

### 6. Apply Corrections

After generating the report:
1. Update the content with verified corrections
2. Add source citations where needed
3. Remove or qualify unverifiable claims
4. Flag any remaining concerns

## Output

### Primary Output
- Complete fact-check report (as above)
- List of required corrections
- Suggested source additions

### File Management
Save the fact-check report to:
- **File Location**: `drafts/seo:fact-check-[topic-slug]-[YYYY-MM-DD].md`

## Integration with Other Commands

### Run After /seo:write
```
/seo:write [topic]
/seo:fact-check drafts/[article-file].md
```

### Run After /seo:rewrite
```
/seo:rewrite [topic]
/seo:fact-check drafts/[article-file].md
```

## Best Practices

1. **Check key claims first** - Focus on statistics and major assertions
2. **Use multiple sources** - Don't rely on a single source
3. **Prefer recent data** - Information changes, especially in tech
4. **Note source dates** - Include publication dates in citations
5. **Err on the side of caution** - When uncertain, qualify or remove
6. **Maintain credibility** - One false claim can undermine the entire article

## Quality Standards

Content passes fact-check when:
- All statistics have verifiable sources
- No claims contradict authoritative sources
- Quotes are accurate and properly attributed
- Comparisons are fair and substantiated
- Technical details are correct

---

**Result**: Content that is factually accurate, properly sourced, and maintains credibility with readers.
