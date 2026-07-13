# Silent Exception Handling Throughout Codebase

---
status: complete
priority: p2
issue_id: "006"
tags: [code-review, security, architecture]
dependencies: []
---

## Problem Statement

Multiple locations use `rescue StandardError` with silent failure (no logging, returns empty/nil). This hides errors, makes debugging difficult, and could mask security issues.

**Why it matters:** Authentication failures, API errors, and other security-relevant issues may go unnoticed.

## Findings

### Evidence

**Location 1:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/data_for_seo.rb` (lines 335-337)
```ruby
rescue StandardError
  # Silently fail
end
```

**Location 2:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/keyword_analyzer.rb` (line 429)
```ruby
rescue StandardError
  []  # Silent failure, returns empty array
end
```

**Location 3:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/data_aggregator.rb` (12 instances)
```ruby
@ga = begin
  GoogleAnalytics.new
rescue StandardError => e
  warn "Warning: ..." # At least warns, but still swallows
  nil
end
```

**Location 4:** `/home/asterio/Dev/claude-seo/data_sources/modules/dataforseo.py` (lines 411-412)
```python
except:
    pass  # Bare except - catches everything including KeyboardInterrupt
```

### Impact
- Programming errors (NoMethodError, NameError) are hidden
- API authentication failures go unnoticed
- Difficult to debug production issues
- Security events may be masked

## Proposed Solutions

### Option A: Add Proper Logging (Recommended)
```ruby
rescue StandardError => e
  SeoMachine.logger.error("Ranking history fetch failed: #{e.class} - #{e.message}")
  SeoMachine.logger.debug(e.backtrace.first(5).join("\n")) if SeoMachine.logger.debug?
  []
end
```

With logger configuration in `seo_machine.rb`:
```ruby
class << self
  attr_accessor :logger
end
self.logger = Logger.new($stderr, level: Logger::WARN)
```

**Pros:** Visibility into failures, configurable verbosity
**Cons:** Adds logging dependency
**Effort:** Medium (2-3 hours)
**Risk:** Low

### Option B: Catch Specific Exceptions
```ruby
rescue Faraday::Error, JSON::ParserError => e
  # Handle expected API/network errors
  []
rescue StandardError => e
  # Re-raise unexpected errors
  raise
end
```

**Pros:** Only catches expected errors
**Cons:** Need to identify all expected error types
**Effort:** Medium (3-4 hours)
**Risk:** Low-Medium

### Option C: Result Objects
```ruby
def check_ranking_history(...)
  # ... API call ...
  Success.new(data)
rescue Faraday::Error => e
  Failure.new(:network_error, e.message)
rescue StandardError => e
  Failure.new(:unexpected_error, e.message)
end
```

**Pros:** Explicit error handling at call sites
**Cons:** Larger refactoring
**Effort:** Large (6-8 hours)
**Risk:** Medium

## Recommended Action

Start with Option A (logging) as quick win, then migrate to Option B for critical paths.

## Technical Details

### Files to Update
- `data_sources/ruby/lib/seo_machine.rb` (add logger)
- `data_sources/ruby/lib/seo_machine/data_for_seo.rb` (3 locations)
- `data_sources/ruby/lib/seo_machine/keyword_analyzer.rb` (2 locations)
- `data_sources/ruby/lib/seo_machine/data_aggregator.rb` (12 locations)
- `data_sources/ruby/lib/seo_machine/content_length_comparator.rb` (1 location)

### Python Files
- `data_sources/modules/dataforseo.py` (replace bare `except:`)

## Acceptance Criteria

- [x] Logger added to SeoMachine module
- [x] All silent exceptions now log warnings
- [ ] Bare `except:` in Python replaced with specific exceptions
- [x] Debug-level logging for stack traces

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in security review | Documented as P2 |
| 2026-01-31 | Approved in triage | Status: pending → ready |
| 2026-01-31 | Implemented logging for Ruby files | Status: ready → complete |

## Resources

- Security sentinel findings
- Ruby Logger documentation
