# Code Duplication: Extract Shared Helpers

---
status: complete
priority: p3
issue_id: "011"
tags: [code-review, refactoring, quality]
dependencies: []
---

## Problem Statement

Several code patterns are duplicated across multiple files, including sentence splitting, markdown header parsing, and grade calculation.

**Why it matters:**
- Bug fixes must be applied in multiple places
- Inconsistent implementations possible
- Unnecessary code bloat

## Findings

### Duplicated Patterns

#### 1. Sentence Splitting (5 locations)
```ruby
sentences = content.split(/[.!?]+/).map(&:strip).reject(&:empty?)
```

**Locations:**
- `readability_scorer.rb:89`
- `readability_scorer.rb:181`
- `readability_scorer.rb:227`
- `seo_quality_rater.rb:420`
- `keyword_analyzer.rb:286`

#### 2. Markdown Header Parsing (2 locations)
```ruby
h1_match = line.match(/^#\s+(.+)$/)
h2_match = line.match(/^##\s+(.+)$/)
h3_match = line.match(/^###\s+(.+)$/)
```

**Locations:**
- `keyword_analyzer.rb:121-146`
- `seo_quality_rater.rb:131-145`

#### 3. Grade Calculation (2 locations - EXACT duplicate)
```ruby
def get_grade(score)
  case score
  when 90..100 then 'A (Excellent)'
  when 80...90 then 'B (Good)'
  when 70...80 then 'C (Average)'
  when 60...70 then 'D (Needs Work)'
  else 'F (Poor)'
  end
end
```

**Locations:**
- `readability_scorer.rb:324-332`
- `seo_quality_rater.rb:452-460`

## Proposed Solutions

### Option A: Create Shared Helpers Module (Recommended)

Create `data_sources/ruby/lib/seo_machine/helpers.rb`:

```ruby
module SeoMachine
  module Helpers
    module TextUtils
      def self.extract_sentences(text)
        text.split(/[.!?]+/).map(&:strip).reject(&:empty?)
      end

      def self.word_count(text)
        text.split.length
      end
    end

    module MarkdownParser
      Header = Struct.new(:level, :text, :line_number)

      def self.extract_headers(content)
        headers = []
        content.each_line.with_index do |line, i|
          if (match = line.match(/^(#+)\s+(.+)$/))
            headers << Header.new(match[1].length, match[2], i)
          end
        end
        headers
      end
    end

    module Scoring
      def self.letter_grade(score)
        case score
        when 90..100 then 'A (Excellent)'
        when 80...90 then 'B (Good)'
        when 70...80 then 'C (Average)'
        when 60...70 then 'D (Needs Work)'
        else 'F (Poor)'
        end
      end
    end
  end
end
```

**Usage:**
```ruby
sentences = SeoMachine::Helpers::TextUtils.extract_sentences(content)
headers = SeoMachine::Helpers::MarkdownParser.extract_headers(content)
grade = SeoMachine::Helpers::Scoring.letter_grade(85)
```

**Pros:** DRY, single source of truth
**Cons:** Adds new file, slight refactoring needed
**Effort:** Medium (2-3 hours)
**Risk:** Low

### Option B: Module Mixins
Include helper methods directly in classes.

**Pros:** Less indirection
**Cons:** Still some duplication in includes
**Effort:** Small (1-2 hours)
**Risk:** Low

## Recommended Action

Implement Option A with helpers module.

## Technical Details

### New File
Create `data_sources/ruby/lib/seo_machine/helpers.rb`

### Files to Update
- `keyword_analyzer.rb` - use TextUtils, MarkdownParser
- `readability_scorer.rb` - use TextUtils, Scoring
- `seo_quality_rater.rb` - use MarkdownParser, Scoring
- `seo_machine.rb` - add autoload for Helpers

### Estimated LOC Reduction
- Sentence splitting: 5 locations × 1 line = 5 lines
- Header parsing: 2 locations × 20 lines = 40 lines
- Grade calculation: 2 locations × 9 lines = 18 lines
- **Total: ~63 lines removed, ~40 lines added = 23 net reduction**

## Acceptance Criteria

- [x] Helpers module created
- [x] All duplicate code replaced with helper calls
- [x] All existing tests pass
- [x] New tests for helper methods

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in pattern analysis | Documented as P3 |
| 2026-01-31 | Approved in triage | Status: pending -> ready |
| 2026-01-31 | Implemented helpers module | Created `helpers.rb` with TextUtils, MarkdownParser, Scoring |
| 2026-01-31 | Refactored files to use helpers | Updated readability_scorer.rb, seo_quality_rater.rb, keyword_analyzer.rb |
| 2026-01-31 | Added tests | Created helpers_test.rb with 18 tests, all passing |
| 2026-01-31 | Completed | Status: ready -> complete |

## Resources

- Pattern recognition specialist findings
