# Missing CLI Entry Points for Ruby Modules

---
status: complete
priority: p2
issue_id: "005"
tags: [code-review, agent-native, architecture]
dependencies: ["001"]
---

## Problem Statement

Ruby analysis modules have no CLI wrappers. Agents must embed inline Ruby code or use `ruby -e` which is error-prone and verbose. There is no `bin/` directory in the Ruby module.

**Why it matters:** Agents cannot easily invoke analysis tools via shell commands, reducing automation capabilities.

## Findings

### Evidence

**Missing directory:** `/home/asterio/Dev/claude-seo/data_sources/ruby/bin/` does not exist

**Current workaround required:**
```bash
ruby -I data_sources/ruby/lib -r seo_machine -e "
  content = File.read('drafts/article.md')
  result = SeoMachine::KeywordAnalyzer.new.analyze(content, 'keyword')
  puts result.to_json
"
```

This is verbose, error-prone, and hard to maintain.

## Proposed Solutions

### Option A: Create CLI Wrappers (Recommended)

Create `data_sources/ruby/bin/` with executable scripts:

```ruby
#!/usr/bin/env ruby
# bin/seo-keywords

require_relative '../lib/seo_machine'
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: seo-keywords [options] KEYWORD"
  opts.on("-f", "--file FILE", "Content file to analyze") { |f| options[:file] = f }
  opts.on("--json", "Output as JSON") { options[:json] = true }
end.parse!

content = options[:file] ? File.read(options[:file]) : ARGF.read
keyword = ARGV[0] || raise("Keyword required")

result = SeoMachine::KeywordAnalyzer.new.analyze(content, keyword)

if options[:json]
  puts JSON.pretty_generate(result)
else
  puts "Keyword: #{keyword}"
  puts "Density: #{result[:primary_keyword][:density]}%"
  puts "Occurrences: #{result[:primary_keyword][:total_occurrences]}"
end
```

**Scripts to create:**
- `bin/seo-keywords` - Keyword analysis
- `bin/seo-readability` - Readability scoring
- `bin/seo-quality` - SEO quality rating
- `bin/seo-scrub` - Content scrubbing
- `bin/seo-intent` - Search intent analysis

**Pros:** Clean CLI interface, easy for agents to invoke
**Cons:** Additional files to maintain
**Effort:** Medium (3-4 hours)
**Risk:** Low

### Option B: Single Unified CLI
```bash
seo-machine analyze keywords --file article.md --keyword "podcast"
seo-machine analyze readability --file article.md
seo-machine scrub --file article.md --output cleaned.md
```

**Pros:** Single entry point, discoverable
**Cons:** More complex to implement
**Effort:** Medium-Large (4-6 hours)
**Risk:** Low

## Recommended Action

Implement Option A first for quick wins, then consider Option B as enhancement.

## Technical Details

### Directory Structure
```
data_sources/ruby/
├── bin/
│   ├── seo-keywords
│   ├── seo-readability
│   ├── seo-quality
│   ├── seo-scrub
│   └── seo-intent
├── lib/
│   └── seo_machine/
└── test/
```

### Installation
Add to Gemfile:
```ruby
spec.executables = Dir['bin/*'].map { |f| File.basename(f) }
```

Or symlink to PATH:
```bash
ln -s $(pwd)/data_sources/ruby/bin/seo-keywords /usr/local/bin/
```

## Acceptance Criteria

- [x] `bin/` directory created with executable scripts
- [x] Each script has `--help` documentation
- [x] Scripts support both file input and stdin
- [x] JSON output mode available
- [x] Scripts are executable (`chmod +x`)

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in agent-native review | Documented as P2 |
| 2026-01-31 | Approved in triage | Status: pending -> ready |
| 2026-01-31 | Implemented CLI wrappers | Created 5 CLI scripts in data_sources/ruby/bin/ |

## Resources

- Agent-native reviewer findings
- Ruby gem packaging best practices
