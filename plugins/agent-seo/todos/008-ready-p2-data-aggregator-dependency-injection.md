# DataAggregator Violates Dependency Inversion

---
status: complete
priority: p2
issue_id: "008"
tags: [code-review, architecture, testing]
dependencies: []
---

## Problem Statement

`DataAggregator` directly instantiates concrete service classes in its constructor instead of receiving them through dependency injection. This creates tight coupling and makes testing difficult.

**Why it matters:**
- Cannot easily mock services in tests
- Hard to test in isolation
- Violates SOLID principles

## Findings

### Evidence

**Location:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/data_aggregator.rb` (lines 12-33)

```ruby
def initialize
  @ga = begin
    GoogleAnalytics.new
  rescue StandardError => e
    warn "Warning: Google Analytics not configured: #{e.message}"
    nil
  end

  @gsc = begin
    GoogleSearchConsole.new
  rescue StandardError => e
    warn "Warning: Google Search Console not configured: #{e.message}"
    nil
  end

  @dfs = begin
    DataForSeo.new
  rescue StandardError => e
    warn "Warning: DataForSEO not configured: #{e.message}"
    nil
  end
end
```

### Impact
- No tests exist for DataAggregator (would require real API credentials)
- Cannot test error handling paths
- Cannot test with mock data sources

## Proposed Solutions

### Option A: Constructor Injection (Recommended)
```ruby
def initialize(ga: nil, gsc: nil, dfs: nil)
  @ga = ga || safe_init { GoogleAnalytics.new }
  @gsc = gsc || safe_init { GoogleSearchConsole.new }
  @dfs = dfs || safe_init { DataForSeo.new }
end

private

def safe_init
  yield
rescue StandardError => e
  warn "Warning: Service not configured: #{e.message}"
  nil
end
```

**Usage in tests:**
```ruby
mock_ga = Minitest::Mock.new
mock_ga.expect(:get_traffic_data, { sessions: 1000 }, [String, Hash])

aggregator = SeoMachine::DataAggregator.new(ga: mock_ga)
result = aggregator.get_comprehensive_page_performance('/page')

mock_ga.verify
```

**Pros:** Simple, backwards compatible, testable
**Cons:** None significant
**Effort:** Small (1-2 hours)
**Risk:** Very Low

### Option B: Factory Pattern
```ruby
class DataAggregator
  class << self
    def build(ga_factory: -> { GoogleAnalytics.new }, ...)
      new(
        ga: safe_build(ga_factory),
        gsc: safe_build(gsc_factory),
        dfs: safe_build(dfs_factory)
      )
    end
  end
end
```

**Pros:** More flexible configuration
**Cons:** More complex API
**Effort:** Medium (2-3 hours)
**Risk:** Low

## Recommended Action

Implement Option A - Simple constructor injection with default creation.

## Technical Details

### Files to Update
- `data_sources/ruby/lib/seo_machine/data_aggregator.rb`

### New Test File
Create `data_sources/ruby/test/data_aggregator_test.rb`:
```ruby
require_relative 'test_helper'

class DataAggregatorTest < Minitest::Test
  def setup
    @mock_ga = Minitest::Mock.new
    @mock_gsc = Minitest::Mock.new
    @mock_dfs = Minitest::Mock.new

    @aggregator = SeoMachine::DataAggregator.new(
      ga: @mock_ga,
      gsc: @mock_gsc,
      dfs: @mock_dfs
    )
  end

  def test_get_priority_queue_with_mock_data
    @mock_gsc.expect(:get_search_performance, mock_gsc_data)
    @mock_ga.expect(:get_traffic_data, mock_ga_data)

    result = @aggregator.get_priority_queue

    assert_kind_of Array, result
    @mock_gsc.verify
    @mock_ga.verify
  end
end
```

## Acceptance Criteria

- [ ] Constructor accepts optional service instances
- [ ] Default behavior unchanged (creates real services)
- [ ] Tests can inject mocks
- [ ] At least 3 test cases for DataAggregator
- [ ] No breaking changes to existing usage

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in architecture review | Documented as P2 |
| 2026-01-31 | Approved in triage | Status: pending → ready |
| 2026-01-31 | Implemented constructor injection | Status: ready → complete |

## Resources

- Architecture strategist findings
- Dependency Inversion Principle
