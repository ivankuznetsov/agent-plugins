# ReDoS Risk in KeywordAnalyzer Regex Pattern

---
status: complete
priority: p1
issue_id: "003"
tags: [code-review, security, critical]
dependencies: []
---

## Problem Statement

User-controlled keywords are interpolated into regex patterns without escaping in KeywordAnalyzer. Malicious input with regex metacharacters could cause unexpected behavior or ReDoS (Regular Expression Denial of Service).

**Why it matters:** A crafted keyword like `(a+)+$` could cause catastrophic backtracking, freezing the application.

## Findings

### Evidence

**Location:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/keyword_analyzer.rb` (lines 82-83)

```ruby
keyword_words = keyword_lower.split
if keyword_words.length > 1
  pattern = Regexp.new("\\b(?:#{keyword_words.join('|')})\\b", Regexp::IGNORECASE)
  matches = content_lower.scan(pattern)
```

### Attack Example
```ruby
# Malicious keyword with regex metacharacters
analyzer.analyze(content, "test.*|[a-z]+")
# Creates regex: /\b(?:test.*|[a-z]+)\b/i
# This matches far more than intended

# ReDoS payload
analyzer.analyze(content, "a]|b]|c]")
# Could cause regex compilation errors or unexpected matches
```

## Proposed Solutions

### Option A: Escape All Keyword Words (Recommended)
```ruby
keyword_words = keyword_lower.split
if keyword_words.length > 1
  escaped_words = keyword_words.map { |w| Regexp.escape(w) }
  pattern = Regexp.new("\\b(?:#{escaped_words.join('|')})\\b", Regexp::IGNORECASE)
  matches = content_lower.scan(pattern)
```

**Pros:** Simple fix, comprehensive protection
**Cons:** None
**Effort:** Small (15 mins)
**Risk:** Very Low

### Option B: Use String Matching Instead
```ruby
# Replace regex with simple string matching
keyword_words = keyword_lower.split
matches = keyword_words.sum do |word|
  content_lower.scan(/\b#{Regexp.escape(word)}\b/).length
end
```

**Pros:** Avoids complex regex entirely
**Cons:** Changes matching behavior slightly
**Effort:** Small (30 mins)
**Risk:** Low

## Recommended Action

Implement Option A - Add `Regexp.escape` to all user-provided pattern components.

## Technical Details

### Affected Files
- `data_sources/ruby/lib/seo_machine/keyword_analyzer.rb` (line 82)

### Similar Patterns to Check
Search for other regex interpolation:
```bash
grep -n 'Regexp.new.*#{' data_sources/ruby/lib/seo_machine/*.rb
```

## Acceptance Criteria

- [x] `Regexp.escape` applied to keyword words
- [ ] Test with special characters (`.`, `*`, `+`, `?`, `|`, `(`, `)`, `[`, `]`)
- [ ] Test with normal keywords still works
- [ ] No performance regression

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in security review | Documented as P1 |
| 2026-01-31 | Approved in triage | Status: pending -> ready |
| 2026-01-31 | Applied Regexp.escape fix | Status: ready -> complete |

## Resources

- Security sentinel findings
- OWASP ReDoS guidelines
