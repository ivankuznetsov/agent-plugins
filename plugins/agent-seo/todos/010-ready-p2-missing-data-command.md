# Missing /data Command for Analytics Access

---
status: complete
priority: p2
issue_id: "010"
tags: [code-review, agent-native, feature]
dependencies: ["001", "005"]
---

## Problem Statement

The powerful data source integrations (GA4, GSC, DataForSEO) have no agent-facing commands. Agents cannot access live performance data to make informed content decisions.

**Why it matters:**
- `DataAggregator` has methods like `get_priority_queue()` and `identify_content_opportunities()` that are inaccessible to agents
- Content decisions are made without performance data
- Manual data gathering required

## Findings

### Evidence

**Powerful methods exist but no commands expose them:**

`/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/data_aggregator.rb`:
- `get_priority_queue()` - Returns prioritized list of content to work on
- `identify_content_opportunities()` - Finds content gaps
- `get_comprehensive_page_performance(url)` - Full page analysis

`/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/google_search_console.rb`:
- `get_quick_wins()` - Keywords with quick ranking potential
- `get_declining_pages()` - Content needing attention
- `get_underperforming_pages()` - Pages not meeting potential

### Current State
- 4 API integration modules exist
- 0 commands to invoke them
- Agents must embed Ruby code inline

## Proposed Solutions

### Option A: Create /data Command (Recommended)

Create `.claude/commands/data.md`:
```markdown
# Data Command

Fetch live performance data from configured sources.

## Usage
`/data [type]`

Types:
- `priority` - Get priority content queue
- `opportunities` - Find content gaps
- `quick-wins` - Keywords near top 10
- `declining` - Pages losing traffic
- `page [url]` - Full page analysis

## Process

### 1. Check Configuration
Verify which data sources are available:
- Google Analytics 4 (GA4_PROPERTY_ID)
- Google Search Console (GSC_SITE_URL)
- DataForSEO (DATAFORSEO_LOGIN)

### 2. Fetch Requested Data
```ruby
require_relative 'data_sources/ruby/lib/seo_machine'

aggregator = SeoMachine::DataAggregator.new

case type
when 'priority'
  aggregator.get_priority_queue
when 'opportunities'
  aggregator.identify_content_opportunities
# ...
end
```

### 3. Present Results
Format as actionable recommendations with metrics.
```

**Pros:** Full access to data capabilities
**Cons:** Requires configured APIs
**Effort:** Medium (3-4 hours)
**Risk:** Low

### Option B: Integrate Data into Existing Commands

Add `--with-data` flag to `/research`, `/write`, `/optimize`:
```
/research podcast monetization --with-data
```

**Pros:** Integrated workflow
**Cons:** More complex implementation
**Effort:** Medium (4-6 hours)
**Risk:** Low

## Recommended Action

Implement Option A first, then consider Option B as enhancement.

## Technical Details

### New File
Create `.claude/commands/data.md`

### Example Output
```markdown
## Content Priority Queue

| Priority | URL | Opportunity | Est. Traffic Gain |
|----------|-----|-------------|-------------------|
| 1 | /blog/podcast-tips | Quick win: rank #8 for "podcast tips" | +500/month |
| 2 | /blog/audio-editing | Declining: -30% in 30 days | Recover +200/month |
| 3 | /guides/hosting | Content gap: competitors cover this | New +1000/month |
```

### Configuration Check
```ruby
def check_data_sources
  {
    ga4: ENV['GA4_PROPERTY_ID'].present?,
    gsc: ENV['GSC_SITE_URL'].present?,
    dataforseo: ENV['DATAFORSEO_LOGIN'].present?
  }
end
```

## Acceptance Criteria

- [x] `/data` command created
- [x] Supports priority, opportunities, quick-wins, declining, page types
- [x] Gracefully handles missing API configuration
- [x] Output is structured for agent consumption
- [x] Documentation updated

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in agent-native review | Documented as P2 |
| 2026-01-31 | Approved in triage | Status: pending -> ready |
| 2026-01-31 | Implemented /data command | Created `.claude/commands/data.md` with full specification |

## Resources

- Agent-native reviewer findings
- DataAggregator source code
