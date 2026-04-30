# Simplify KeywordAnalyzer: Remove Unused Features

---
status: complete
priority: p3
issue_id: "012"
tags: [code-review, simplification, yagni]
dependencies: ["004"]
---

## Problem Statement

KeywordAnalyzer contains ~117 lines of unused or low-value features: topic clustering, LSI keywords, and distribution heatmaps. These are not tested and add complexity without clear value.

**Why it matters:**
- YAGNI violation
- Maintenance burden
- Confusing API surface

## Findings

### Unused Features

#### 1. Topic Clustering (45 LOC)
**Location:** `keyword_analyzer.rb:313-357`
- Simple term-frequency clustering, not actual ML clustering
- Not tested in test file
- Returns "Insufficient sections" for most content

#### 2. LSI Keywords (45 LOC)
**Location:** `keyword_analyzer.rb:387-431`
- Misleadingly named - just extracts common words
- Not actual Latent Semantic Indexing
- Returns empty array on error (silent failure)

#### 3. Distribution Heatmap (27 LOC)
**Location:** `keyword_analyzer.rb:359-385`
- Duplicates `analyze_section_distribution` logic
- Arbitrary heat levels 0-5
- Not used by any consumer

### Test Coverage
Tests only verify:
- `density`, `count`, `placements`, `assessment`
- None of clustering, LSI, or heatmap features

## Proposed Solutions

### Option A: Remove Unused Features (Recommended)
Delete the three unused methods and simplify return structure.

```ruby
def analyze(content, primary_keyword, secondary_keywords: [], target_density: 1.5)
  word_count = content.split.length
  sections = extract_sections(content)

  primary_analysis = analyze_keyword(content, primary_keyword, word_count, sections, target_density)
  secondary_analysis = secondary_keywords.map { |kw| analyze_keyword(content, kw, ...) }
  stuffing_risk = detect_keyword_stuffing(content, primary_keyword, primary_analysis[:density])

  {
    word_count: word_count,
    primary_keyword: primary_analysis,
    secondary_keywords: secondary_analysis,
    keyword_stuffing: stuffing_risk,
    recommendations: generate_recommendations(...)
  }
end
```

**Removed:**
- `perform_clustering` method (-45 LOC)
- `create_distribution_heatmap` method (-27 LOC)
- `find_lsi_keywords` method (-45 LOC)
- Related return keys

**Pros:** Simpler, cleaner API, less code to maintain
**Cons:** Breaking change if anyone uses these features
**Effort:** Small (1-2 hours)
**Risk:** Low (features unused based on tests)

### Option B: Move to Separate Module
Extract to `SeoMachine::AdvancedKeywordAnalyzer`.

**Pros:** Keeps features available
**Cons:** Still maintains unused code
**Effort:** Medium (2-3 hours)
**Risk:** Low

## Recommended Action

Implement Option A - Remove the unused features.

## Technical Details

### Lines to Remove

| Method | Lines | LOC |
|--------|-------|-----|
| `perform_clustering` | 313-357 | 45 |
| `create_distribution_heatmap` | 359-385 | 27 |
| `find_lsi_keywords` | 387-431 | 45 |
| **Total** | | **117** |

### Files to Update
- `data_sources/ruby/lib/seo_machine/keyword_analyzer.rb`

### New Line Count
Current: 483 lines
After removal: ~366 lines (-24%)

## Acceptance Criteria

- [ ] Three unused methods removed
- [ ] Return structure simplified
- [ ] All existing tests pass
- [ ] README updated if needed

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in simplicity review | Documented as P3 |
| 2026-01-31 | Approved in triage | Status: pending -> ready |
| 2026-01-31 | Removed unused methods | Status: ready -> complete |

## Resources

- Code simplicity reviewer findings
- YAGNI principle
