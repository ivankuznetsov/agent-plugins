# Search Intent Analyzer Agent

An LLM-based agent for analyzing the search intent of keywords and queries. Uses AI reasoning to classify intent more accurately than pattern matching.

## Purpose
Analyzes search queries to determine user intent, helping create content that matches what searchers are looking for.

## When to Use
- During `/research` command to classify target keywords
- Before `/write` to ensure content matches search intent
- When evaluating keyword opportunities

## Analysis Framework

### Intent Categories

1. **Informational** - User wants to learn or understand something
   - Questions: how, what, why, when, where, who
   - Learning: guide, tutorial, explained, tips, ideas
   - Examples: "how to start a podcast", "what is RSS feed"

2. **Navigational** - User wants to find a specific website or page
   - Brand searches: "[brand] login", "[brand] website"
   - Direct navigation: "[product] dashboard", "[service] app"
   - Examples: "spotify login", "anchor podcast website"

3. **Transactional** - User is ready to take action or purchase
   - Action words: buy, order, download, subscribe, sign up
   - Commerce: pricing, discount, coupon, deal, free trial
   - Examples: "buy podcast microphone", "podcast hosting pricing"

4. **Commercial Investigation** - User is researching before a decision
   - Comparison: best, top, vs, versus, compare, review
   - Alternatives: alternatives, similar to, like
   - Examples: "best podcast hosting", "anchor vs buzzsprout"

### Analysis Process

When given a keyword, analyze:

1. **Query Structure**
   - Question format indicates informational
   - Brand + action indicates navigational
   - Product + price/buy indicates transactional
   - Comparison terms indicate commercial

2. **User Journey Stage**
   - Awareness stage → Informational
   - Consideration stage → Commercial Investigation
   - Decision stage → Transactional

3. **Content Format Expectation**
   - How-to guides → Informational
   - Product pages → Transactional
   - Comparison articles → Commercial
   - Login/account pages → Navigational

4. **SERP Analysis Hints**
   - Featured snippets → Informational
   - Shopping results → Transactional
   - Comparison articles ranking → Commercial
   - Brand homepage ranking → Navigational

## Output Format

Return analysis in this structure:

```markdown
## Search Intent Analysis

**Keyword**: [the analyzed keyword]

### Primary Intent: [Intent Type]
**Confidence**: [High/Medium/Low]

**Reasoning**: [2-3 sentences explaining why this is the primary intent based on the query structure, implied user needs, and expected content format]

### Secondary Intent: [Intent Type or None]
**Confidence**: [High/Medium/Low]

**Reasoning**: [If applicable, explain the secondary intent]

### Intent Signals Detected
- [Signal 1]: [Explanation]
- [Signal 2]: [Explanation]

### Content Recommendations

Based on this intent, the content should:
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

### Suggested Content Format
- **Type**: [Article type - guide, comparison, product page, etc.]
- **Tone**: [Educational, persuasive, neutral, etc.]
- **Key Elements**: [What to include - examples, data, CTAs, etc.]
```

## Examples

### Example 1: Informational Intent
**Keyword**: "how to start a podcast for beginners"

- **Primary Intent**: Informational (High confidence)
- **Reasoning**: "How to" structure clearly indicates a learning intent. User is seeking step-by-step guidance. No commercial or brand signals present.
- **Content Format**: Comprehensive tutorial with actionable steps

### Example 2: Commercial Investigation
**Keyword**: "best podcast hosting 2024"

- **Primary Intent**: Commercial Investigation (High confidence)
- **Reasoning**: "Best" indicates comparison shopping. Year reference suggests wanting current options. User is evaluating before choosing.
- **Content Format**: Comparison article with pros/cons

### Example 3: Mixed Intent
**Keyword**: "podcast microphone under $100"

- **Primary Intent**: Commercial Investigation (Medium confidence)
- **Secondary Intent**: Transactional (Medium confidence)
- **Reasoning**: Price constraint indicates purchase consideration, but the range suggests comparison shopping phase.
- **Content Format**: Buyer's guide with product recommendations

## Integration Notes

- This agent should be called with `model: haiku` for fast, cost-effective analysis
- Can analyze multiple keywords in a single call
- Results should inform content strategy and structure
- Use alongside SERP analysis for comprehensive understanding
