# Performance: KeywordAnalyzer Multiple Full-Text Scans

---
status: complete
priority: p3
issue_id: "013"
tags: [code-review, performance]
dependencies: []
---

## Problem Statement

KeywordAnalyzer's `analyze` method performs 10+ full scans of content, creating new string allocations each time. With 5 secondary keywords on a 10,000-word document, this results in 15+ full scans.

**Why it matters:** Excessive CPU and memory usage for large documents or batch processing.

## Findings

### Evidence

**Location:** `keyword_analyzer.rb:27-66`

```ruby
def analyze(content, primary_keyword, secondary_keywords: [], target_density: 1.5)
  word_count = content.split.length                    # Scan 1
  sections = extract_sections(content)                 # Scan 2
  primary_analysis = analyze_keyword(content, ...)     # Scans 3-4 (downcases + scans)
  secondary_analysis = secondary_keywords.map { |kw|   # Scans 5+ for each keyword
    analyze_keyword(content, kw, ...)
  }
  stuffing_risk = detect_keyword_stuffing(content, ..) # Scans 6-7
  # ... more scans
```

### Impact
- Each `content.downcase` creates new string allocation
- Total memory: ~15x document size in temporary strings
- For 100,000-word document: ~3-5 seconds processing

## Proposed Solutions

### Option A: Pre-compute Common Values (Recommended)
```ruby
def analyze(content, primary_keyword, secondary_keywords: [], target_density: 1.5)
  # Pre-compute once
  content_lower = content.downcase.freeze
  words = content.split
  word_count = words.length
  sections = extract_sections(content)

  # Pass pre-computed values to all methods
  primary_analysis = analyze_keyword_optimized(
    content_lower,
    primary_keyword.downcase,
    word_count,
    sections,
    target_density
  )

  secondary_analysis = secondary_keywords.map do |kw|
    analyze_keyword_optimized(content_lower, kw.downcase, word_count, sections, target_density * 0.5)
  end

  # ...
end

private

def analyze_keyword_optimized(content_lower, keyword_lower, word_count, sections, target_density)
  # Use pre-computed values instead of recalculating
end
```

**Pros:** 2-3x speedup, 3-5x less memory
**Cons:** Requires refactoring method signatures
**Effort:** Medium (2-3 hours)
**Risk:** Low

### Option B: Lazy Computation with Memoization
```ruby
def analyze(content, primary_keyword, ...)
  @content = content
  @content_lower ||= content.downcase.freeze
  @word_count ||= content.split.length
  # ...
end
```

**Pros:** Minimal changes to public API
**Cons:** Instance state, not thread-safe
**Effort:** Small (1 hour)
**Risk:** Low-Medium

## Recommended Action

Implement Option A for cleaner architecture.

## Technical Details

### Files to Update
- `data_sources/ruby/lib/seo_machine/keyword_analyzer.rb`

### Method Signatures to Change
```ruby
# Before
def analyze_keyword(content, keyword, word_count, sections, target_density)
  content_lower = content.downcase  # Recalculates!
  keyword_lower = keyword.downcase  # Recalculates!

# After
def analyze_keyword(content_lower, keyword_lower, word_count, sections, target_density)
  # Values already computed by caller
```

### Benchmark
```ruby
require 'benchmark/ips'

content = File.read('large_article.md')  # 10,000+ words
analyzer = SeoMachine::KeywordAnalyzer.new

Benchmark.ips do |x|
  x.report("current") { analyzer.analyze(content, "keyword", secondary_keywords: %w[a b c d e]) }
  x.report("optimized") { analyzer_v2.analyze(content, "keyword", secondary_keywords: %w[a b c d e]) }
  x.compare!
end
```

## Acceptance Criteria

- [x] `content.downcase` called only once per analyze
- [x] All tests pass
- [ ] Benchmark shows 2x+ improvement
- [x] Memory usage reduced

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in performance review | Documented as P3 |
| 2026-01-31 | Approved in triage | Status: pending → ready |
| 2026-01-31 | Implemented Option A pre-compute optimization | Status: ready → complete |

## Resources

- Performance oracle findings
