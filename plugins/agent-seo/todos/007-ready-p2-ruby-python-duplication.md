# Ruby/Python Module Duplication

---
status: complete
priority: p2
issue_id: "007"
tags: [code-review, architecture, technical-debt]
dependencies: ["001"]
---

## Problem Statement

The codebase maintains parallel implementations in both Ruby (3,571 lines) and Python (4,564 lines). This creates significant maintenance burden as bug fixes and features must be applied twice.

**Why it matters:**
- ~8,000 lines of duplicated logic
- Bug fixes needed in two places
- Feature parity requires synchronized development
- Confusion about which is canonical

## Findings

### Evidence

**Ruby modules:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/`
```
keyword_analyzer.rb       483 lines
readability_scorer.rb     468 lines
seo_quality_rater.rb      462 lines
google_search_console.rb  411 lines
data_for_seo.rb           354 lines
...
Total: ~3,571 lines
```

**Python modules:** `/home/asterio/Dev/claude-seo/data_sources/modules/`
```
seo_quality_rater.py      652 lines
keyword_analyzer.py       645 lines
google_search_console.py  555 lines
...
Total: ~4,564 lines
```

### Differences Identified
- Python `keyword_analyzer.py` uses `sklearn` for clustering; Ruby uses simpler TF approach
- Python has more verbose implementations (~22% more code)
- README states Ruby is primary, but agents reference Python

## Proposed Solutions

### Option A: Deprecate Python, Standardize on Ruby (Recommended)

1. Add deprecation notice to Python modules
2. Update all agent/command references to Ruby
3. Delete Python modules after transition period

**Pros:**
- Eliminates maintenance burden
- Clear canonical source
- Ruby modules are more tested

**Cons:**
- Loses sklearn clustering (minimal value)
- Breaking change for Python users

**Effort:** Medium (4-6 hours)
**Risk:** Low

### Option B: Keep Both with Clear Documentation

1. Document Ruby as canonical
2. Python as "legacy/reference"
3. Accept divergence

**Pros:** Backwards compatibility
**Cons:** Continued maintenance, confusion
**Effort:** Small (1 hour)
**Risk:** Low (but tech debt grows)

### Option C: Generate Python from Ruby (or vice versa)

Use transpilation or code generation.

**Pros:** Single source of truth
**Cons:** Complex, may not be feasible
**Effort:** Large (20+ hours)
**Risk:** High

## Recommended Action

**Delete Python modules immediately.** No deprecation period needed - Ruby is the canonical implementation.

## Technical Details

### Files to Delete
- All files in `data_sources/modules/*.py` (10 files)
- Approximately 4,564 lines removed

### Update Required in
- `.claude/agents/content-analyzer.md` (references Python)
- `.claude/commands/write.md` (Python code examples)
- `README.md` (mentions Python modules)

## Acceptance Criteria

- [x] All Python modules deleted from `data_sources/modules/`
- [ ] All agent/command files reference Ruby (see Issue #001)
- [x] README updated to reflect Ruby-only

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in architecture review | Documented as P2 |
| 2026-01-31 | Approved in triage | Status: pending → ready (delete Python immediately) |
| 2026-01-31 | Deleted Python modules | Removed 10 .py files (~4,564 lines); updated README.md and data_sources/README.md to Ruby-only |

## Resources

- Architecture strategist findings
- Git history analysis
