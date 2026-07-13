# Missing Tests for API Integration Classes

---
status: complete
priority: p3
issue_id: "014"
tags: [code-review, testing]
dependencies: ["008"]
---

## Problem Statement

Four API integration classes have no test coverage: DataForSeo, GoogleAnalytics, GoogleSearchConsole, and DataAggregator. This represents a significant gap in quality assurance.

**Why it matters:**
- No confidence in API client behavior
- Breaking changes go undetected
- Error handling paths untested

## Findings

### Test Coverage Gap

| Module | Lines | Test File | Coverage |
|--------|-------|-----------|----------|
| `DataForSeo` | 354 | None | 0% |
| `GoogleAnalytics` | 321 | None | 0% |
| `GoogleSearchConsole` | 411 | None | 0% |
| `DataAggregator` | 278 | None | 0% |
| **Total** | **1,364** | | **0%** |

### Contrast with Tested Modules

| Module | Lines | Test File | Tests |
|--------|-------|-----------|-------|
| `KeywordAnalyzer` | 483 | Yes | 20 |
| `ReadabilityScorer` | 468 | Yes | 23 |
| `SeoQualityRater` | 462 | Yes | 22 |
| `ContentScrubber` | 241 | Yes | 24 |

## Proposed Solutions

### Option A: Add Tests with Mocks (Recommended)

Use Minitest mocks or WebMock for API responses.

**DataForSeo test example:**
```ruby
require_relative 'test_helper'
require 'webmock/minitest'

class DataForSeoTest < Minitest::Test
  def setup
    ENV['DATAFORSEO_LOGIN'] = 'test'
    ENV['DATAFORSEO_PASSWORD'] = 'test'
    @client = SeoMachine::DataForSeo.new
  end

  def test_get_rankings_parses_response
    stub_request(:post, "https://api.dataforseo.com/v3/serp/google/organic/live/advanced")
      .to_return(body: fixture('dataforseo_rankings.json'))

    result = @client.get_rankings(domain: 'example.com', keywords: ['test'])

    assert_kind_of Array, result
    assert result.first.key?(:keyword)
  end

  def test_handles_api_error
    stub_request(:post, /dataforseo/).to_return(status: 500)

    result = @client.get_rankings(domain: 'example.com', keywords: ['test'])

    assert_empty result  # or assert_raises depending on desired behavior
  end
end
```

**Pros:** Comprehensive testing, no real API calls
**Cons:** Fixtures may drift from real API
**Effort:** Large (6-8 hours for all 4 classes)
**Risk:** Low

### Option B: Integration Tests with VCR

Use VCR gem to record/replay real API responses.

**Pros:** Real responses, more realistic
**Cons:** Requires API credentials, cassettes can be large
**Effort:** Large (8-10 hours)
**Risk:** Low

## Recommended Action

Implement Option A with WebMock for unit tests. Consider Option B for integration tests later.

## Technical Details

### New Files to Create
- `test/data_for_seo_test.rb`
- `test/google_analytics_test.rb`
- `test/google_search_console_test.rb`
- `test/data_aggregator_test.rb`
- `test/fixtures/` (JSON response fixtures)

### Dependencies to Add
```ruby
# Gemfile
group :test do
  gem 'webmock'
end
```

### Test Categories per Class

**DataForSeo:**
- `get_rankings` - success, empty, error
- `get_serp_data` - success, error
- `get_keyword_ideas` - success, filtering
- Authentication setup

**GoogleAnalytics:**
- `get_traffic_data` - success, date ranges
- `get_real_time_users` - success
- Configuration errors

**GoogleSearchConsole:**
- `get_search_performance` - success, filters
- `get_quick_wins` - calculation logic
- `get_declining_pages` - trend calculation

**DataAggregator:**
- Integration of multiple sources
- Handling missing sources gracefully
- Priority queue calculation

## Acceptance Criteria

- [x] Test files created for all 4 classes
- [x] At least 5 tests per class
- [x] WebMock fixtures for API responses
- [x] Error handling paths tested
- [x] All tests pass in CI

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in pattern analysis | Documented as P3 |
| 2026-01-31 | Approved in triage | Status: pending → ready |
| 2026-01-31 | Implemented comprehensive tests | Created 58 tests (15 DataForSeo, 11 GoogleAnalytics, 14 GoogleSearchConsole, 18 DataAggregator); fixed typo in GSC source; fixed ContentLengthComparator test issues |

## Resolution Notes

Test files created with comprehensive coverage:
- `data_for_seo_test.rb` - 15 tests using WebMock for HTTP stubbing
- `google_analytics_test.rb` - 11 tests using Minitest::Mock for Google API
- `google_search_console_test.rb` - 14 tests using Minitest::Mock for Google API
- `data_aggregator_test.rb` - 18 tests using dependency injection with mocks

JSON fixtures created in `test/fixtures/`:
- `dataforseo_rankings.json`
- `dataforseo_serp_data.json`
- `dataforseo_keyword_ideas.json`
- `dataforseo_domain_metrics.json`

Bug fix: Corrected typo in `google_search_console.rb:293` (`query_search_analytics` → `query_searchanalytic`)

## Resources

- Pattern recognition specialist findings
- WebMock documentation
