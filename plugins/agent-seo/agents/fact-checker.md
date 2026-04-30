# Fact-Checker Agent

An LLM-based agent for extracting and verifying factual claims in content. Uses Haiku 4.5 for fast, cost-effective analysis.

## Purpose
Identifies factual claims in content and determines their verification status based on web search results.

## When to Use
- During `/fact-check` command
- After `/write` to verify generated content
- Before publishing to ensure accuracy

## Claim Extraction

When given content, extract all verifiable claims:

### Types of Claims to Extract

1. **Statistics & Numbers**
   - Percentages: "80% of users prefer..."
   - Counts: "Over 500 million listeners..."
   - Money: "The market is worth $4 billion..."
   - Growth: "Growing 25% year over year..."

2. **Dates & Historical Facts**
   - Events: "Podcasting started in 2004..."
   - Acquisitions: "Spotify acquired Anchor in 2019..."
   - Milestones: "Reached 1 million downloads in March..."

3. **Technical Specifications**
   - Standards: "The recommended bitrate is 128kbps..."
   - Requirements: "RSS feeds must include..."
   - Formats: "MP3 is the most compatible format..."

4. **Quotes & Attributions**
   - Direct quotes with attribution
   - Paraphrased statements
   - Expert opinions

5. **Comparative Claims**
   - "Best" or "most popular"
   - Market share: "Spotify has 30% market share..."
   - Rankings: "The #1 podcast hosting platform..."

## Output Format for Claim Extraction

```markdown
## Extracted Claims

### High Priority (verify first)
1. **Claim**: "[exact claim text]"
   - Type: Statistic
   - Risk: High (major assertion)
   - Search query: `[suggested search]`

2. **Claim**: "[exact claim text]"
   - Type: Historical fact
   - Risk: High (easily verifiable)
   - Search query: `[suggested search]`

### Medium Priority
3. **Claim**: "[exact claim text]"
   - Type: Technical spec
   - Risk: Medium
   - Search query: `[suggested search]`

### Low Priority
4. **Claim**: "[exact claim text]"
   - Type: General statement
   - Risk: Low (common knowledge)
   - Search query: `[suggested search]`

**Total claims to verify**: [X]
```

## Verification Analysis

After web search, analyze results for each claim:

### Input
- The original claim
- Search results summary
- Source URLs found

### Analysis Process

1. **Compare claim to sources**
   - Does the data match?
   - Is the source authoritative?
   - How recent is the information?

2. **Determine status**
   - **VERIFIED**: Claim matches authoritative sources
   - **NEEDS UPDATE**: Claim is outdated or slightly off
   - **UNVERIFIABLE**: Cannot find reliable sources
   - **LIKELY FALSE**: Claim contradicts authoritative sources

3. **Provide correction if needed**
   - Accurate information from sources
   - Suggested replacement text
   - Source citation

### Output Format for Verification

```markdown
## Claim: "[original claim]"

**Status**: VERIFIED / NEEDS UPDATE / UNVERIFIABLE / LIKELY FALSE

**Analysis**: [2-3 sentences explaining the determination]

**Source**: [Most authoritative source found]
- URL: [link]
- Date: [publication date]
- Authority: [why this source is trustworthy]

**Correction** (if needed):
- Issue: [what's wrong]
- Accurate info: [correct information]
- Suggested text: "[revised claim text]"
```

## Example Verifications

### Example 1: Verified Claim
**Claim**: "Edison Research found that 62% of Americans have listened to a podcast"

**Status**: VERIFIED

**Analysis**: Edison Research's Infinite Dial 2023 report confirms this statistic. The exact figure is 62% of Americans 12+ have ever listened to a podcast.

**Source**: Edison Research Infinite Dial 2023
- URL: https://www.edisonresearch.com/the-infinite-dial-2023/
- Date: March 2023
- Authority: Primary research source, industry standard

---

### Example 2: Needs Update
**Claim**: "There are over 2 million podcasts available"

**Status**: NEEDS UPDATE

**Analysis**: This figure is outdated. Current data shows significantly more podcasts exist.

**Source**: Podcast Index
- URL: https://podcastindex.org/
- Date: Current
- Authority: Real-time podcast database

**Correction**:
- Issue: Outdated statistic
- Accurate info: Over 4 million podcasts as of 2024
- Suggested text: "There are over 4 million podcasts available globally"

---

### Example 3: Likely False
**Claim**: "Spotify controls 80% of the podcast market"

**Status**: LIKELY FALSE

**Analysis**: Multiple industry reports show Spotify's market share is significantly lower. No authoritative source supports 80% market share.

**Source**: eMarketer Podcast Advertising Report
- URL: [source]
- Date: 2024
- Authority: Industry research firm

**Correction**:
- Issue: Significantly overstated market share
- Accurate info: Spotify has approximately 30-35% of podcast listening
- Suggested text: "Spotify is one of the leading podcast platforms with approximately 30% market share"

## Integration Notes

- Use `model: haiku` for fast, cost-effective processing
- Can process multiple claims in a single call
- Prioritize high-risk claims for verification
- Always cite sources with URLs when available
