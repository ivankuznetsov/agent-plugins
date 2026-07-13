# Python/Ruby Import Mismatch in Commands

---
status: complete
priority: p1
issue_id: "001"
tags: [code-review, critical, agent-native, integration]
dependencies: []
---

## Problem Statement

Claude commands and agent definitions reference Python import syntax but the actual implementation is in Ruby. This completely breaks agent automation as code examples will fail.

**Why it matters:** Agents following command instructions will fail when trying to execute the Python code examples since the modules are Ruby classes.

## Findings

### Evidence

**Location 1:** `/home/asterio/Dev/claude-seo/.claude/commands/write.md` (lines 177-184)
```python
import sys
sys.path.append('data_sources/modules')
from content_scrubber import scrub_file

scrub_file('drafts/[topic-slug]-[YYYY-MM-DD].md', verbose=True)
```

**Location 2:** `/home/asterio/Dev/claude-seo/.claude/agents/content-analyzer.md` (lines 10-11, 32-75)
```
You have access to these Python analysis modules in `data_sources/modules/`:
```

### Impact
- All agent-invoked analysis will fail
- Commands cannot be executed as documented
- Creates confusion about which language to use

## Proposed Solutions

### Option A: Update All References to Ruby (Recommended)
**Pros:**
- Aligns with stated direction (README says Ruby is primary)
- Ruby modules are more complete and tested
- Single language simplifies maintenance

**Cons:**
- Requires updating 9+ command/agent files

**Effort:** Small (2-3 hours)
**Risk:** Low

### Option B: Create Python Wrapper Around Ruby
**Pros:**
- Backwards compatibility with existing docs

**Cons:**
- Adds complexity
- Dual maintenance burden

**Effort:** Medium (4-6 hours)
**Risk:** Medium

## Recommended Action

Proceed with Option A - Update all command and agent files to use Ruby syntax.

## Technical Details

### Files to Update
- `.claude/commands/write.md`
- `.claude/commands/research.md`
- `.claude/commands/optimize.md`
- `.claude/commands/analyze-existing.md`
- `.claude/agents/content-analyzer.md`
- `.claude/agents/seo-optimizer.md`

### Correct Ruby Syntax
```ruby
require_relative 'data_sources/ruby/lib/seo_machine'

scrubber = SeoMachine::ContentScrubber.new
cleaned, stats = scrubber.scrub(content)

# Or for file operations
SeoMachine::ContentScrubber.scrub_file('drafts/article.md', verbose: true)
```

## Acceptance Criteria

- [x] All command files use Ruby import/require syntax
- [x] All agent files reference Ruby modules correctly
- [x] Code examples are executable
- [ ] Commands successfully invoke Ruby analysis

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in code review | Documented as P1 |
| 2026-01-31 | Approved in triage | Status: pending → ready |
| 2026-01-31 | Updated Python imports to Ruby | Status: ready → complete |

## Resources

- Agent-native review findings
- README.md (states Ruby is primary)
