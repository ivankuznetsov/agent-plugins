# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'

class DataAggregatorTest < Minitest::Test
  def setup
    # Create mock services for dependency injection
    @mock_ga = Minitest::Mock.new
    @mock_gsc = Minitest::Mock.new
    @mock_dfs = Minitest::Mock.new
  end

  def teardown
    # Verify all expectations were met
    @mock_ga.verify if @mock_ga.respond_to?(:verify)
    @mock_gsc.verify if @mock_gsc.respond_to?(:verify)
    @mock_dfs.verify if @mock_dfs.respond_to?(:verify)
  end

  # Initialization tests
  def test_initialization_with_injected_services
    # Use simple objects instead of mocks for this test
    ga = Object.new
    gsc = Object.new
    dfs = Object.new

    aggregator = AgentSeo::DataAggregator.new(ga: ga, gsc: gsc, dfs: dfs)

    assert_instance_of AgentSeo::DataAggregator, aggregator
    assert_same ga, aggregator.ga
    assert_same gsc, aggregator.gsc
    assert_same dfs, aggregator.dfs
  end

  def test_initialization_handles_missing_services_gracefully
    # When no services are injected and env vars are not set,
    # the aggregator should still initialize with nil services
    aggregator = AgentSeo::DataAggregator.new(ga: nil, gsc: nil, dfs: nil)

    assert_instance_of AgentSeo::DataAggregator, aggregator
    assert_nil aggregator.ga
    assert_nil aggregator.gsc
    assert_nil aggregator.dfs
  end

  # get_comprehensive_page_performance tests
  def test_get_comprehensive_page_performance_returns_all_data
    url = '/blog/test-article'

    ga_trends = {
      total_pageviews: 1500,
      trend_direction: 'rising',
      trend_percent: 25.5,
      timeline: [{ period: '202501', pageviews: 500 }]
    }

    gsc_performance = {
      url: url,
      clicks: 200,
      impressions: 5000,
      ctr: 4.0,
      avg_position: 8.5,
      top_keywords: [
        { keyword: 'test keyword', clicks: 100, impressions: 2500, position: 7.0 }
      ]
    }

    dfs_rankings = [
      { keyword: 'test keyword', domain: 'example.com', position: 7, ranking: true }
    ]

    @mock_ga.expect(:get_page_trends, ga_trends, [url], days: 30)
    @mock_gsc.expect(:get_page_performance, gsc_performance, [url], days: 30)
    @mock_dfs.expect(:get_rankings, dfs_rankings) do |args|
      args[:keywords].include?('test keyword')
    end

    ENV['GSC_SITE_URL'] = 'https://example.com'

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: @mock_dfs)
    result = aggregator.get_comprehensive_page_performance(url, days: 30)

    assert_kind_of Hash, result
    assert_equal url, result[:url]
    assert result.key?(:analyzed_at)
    assert_equal 30, result[:period_days]

    # Check GA4 data
    assert result[:ga4]
    assert_equal 1500, result[:ga4][:total_pageviews]
    assert_equal 'rising', result[:ga4][:trend_direction]

    # Check GSC data
    assert result[:gsc]
    assert_equal 200, result[:gsc][:clicks]
    assert_equal 5000, result[:gsc][:impressions]

    # Check DataForSEO data
    assert result[:dataforseo]
    assert result[:dataforseo][:rankings]

    ENV.delete('GSC_SITE_URL')
  end

  def test_get_comprehensive_page_performance_handles_ga_error
    url = '/blog/test-article'

    @mock_ga.expect(:get_page_trends, nil) { raise StandardError, 'GA4 API Error' }

    gsc_performance = {
      url: url,
      clicks: 100,
      impressions: 2000,
      ctr: 5.0,
      avg_position: 6.0,
      top_keywords: []
    }
    @mock_gsc.expect(:get_page_performance, gsc_performance, [url], days: 30)

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_comprehensive_page_performance(url, days: 30)

    # GA4 should have error, GSC should still work
    assert result[:ga4].key?(:error)
    assert_equal 'GA4 API Error', result[:ga4][:error]
    assert_equal 100, result[:gsc][:clicks]
  end

  def test_get_comprehensive_page_performance_works_without_ga
    url = '/blog/test-article'

    gsc_performance = {
      url: url,
      clicks: 150,
      impressions: 3000,
      ctr: 5.0,
      avg_position: 7.5,
      top_keywords: []
    }
    @mock_gsc.expect(:get_page_performance, gsc_performance, [url], days: 30)

    aggregator = AgentSeo::DataAggregator.new(ga: nil, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_comprehensive_page_performance(url, days: 30)

    assert_nil result[:ga4]
    assert_equal 150, result[:gsc][:clicks]
  end

  # identify_content_opportunities tests
  def test_identify_content_opportunities_returns_all_categories
    quick_wins = [
      { keyword: 'quick win keyword', position: 12, impressions: 1000, opportunity_score: 85.5 }
    ]

    declining_pages = [
      { path: '/blog/old-article', title: 'Old Article', change_percent: -35.0, pageviews: 100 }
    ]

    low_ctr_pages = [
      { url: '/blog/low-ctr', impressions: 2000, ctr: 1.5, missed_clicks: 70 }
    ]

    trending_queries = [
      { query: 'trending topic', recent_impressions: 500, change_percent: 150.0 }
    ]

    @mock_gsc.expect(:get_quick_wins, quick_wins, days: 30)
    @mock_ga.expect(:get_declining_pages, declining_pages, comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, low_ctr_pages, days: 30)
    @mock_gsc.expect(:get_trending_queries, trending_queries)

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.identify_content_opportunities(days: 30)

    assert_kind_of Hash, result
    assert result.key?(:quick_wins)
    assert result.key?(:declining_content)
    assert result.key?(:low_ctr)
    assert result.key?(:trending_topics)
    assert result.key?(:competitor_gaps)

    assert_equal 1, result[:quick_wins].size
    assert_equal 'quick win keyword', result[:quick_wins].first[:keyword]

    assert_equal 1, result[:declining_content].size
    assert_equal '/blog/old-article', result[:declining_content].first[:path]
  end

  def test_identify_content_opportunities_handles_service_errors
    @mock_gsc.expect(:get_quick_wins, nil) { raise StandardError, 'GSC Error' }
    @mock_gsc.expect(:get_low_ctr_pages, nil) { raise StandardError, 'GSC Error' }
    @mock_gsc.expect(:get_trending_queries, nil) { raise StandardError, 'GSC Error' }
    @mock_ga.expect(:get_declining_pages, nil) { raise StandardError, 'GA Error' }

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.identify_content_opportunities

    # Should return structure with empty arrays, not raise
    assert_kind_of Hash, result
    assert_empty result[:quick_wins]
    assert_empty result[:declining_content]
    assert_empty result[:low_ctr]
    assert_empty result[:trending_topics]
  end

  # generate_performance_report tests
  def test_generate_performance_report_returns_complete_report
    top_pages = [
      { path: '/blog/top-article', title: 'Top Article', pageviews: 5000, sessions: 4000, engagement_rate: 0.75 }
    ]

    keywords = [
      { keyword: 'test keyword', clicks: 200, impressions: 5000, ctr: 0.04 }
    ]

    # Set up expectations for identify_content_opportunities
    @mock_ga.expect(:get_top_pages, top_pages, days: 30, limit: 100)
    @mock_gsc.expect(:get_keyword_positions, keywords, days: 30)

    # identify_content_opportunities is called within generate_performance_report
    @mock_gsc.expect(:get_quick_wins, [], days: 30)
    @mock_ga.expect(:get_declining_pages, [], comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, [], days: 30)
    @mock_gsc.expect(:get_trending_queries, [])

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.generate_performance_report(days: 30)

    assert_kind_of Hash, result
    assert result.key?(:generated_at)
    assert_equal 30, result[:period_days]

    # Check summary
    assert result[:summary].key?(:total_pageviews)
    assert_equal 5000, result[:summary][:total_pageviews]
    assert result[:summary].key?(:total_keywords)
    assert_equal 1, result[:summary][:total_keywords]
    assert result[:summary].key?(:total_clicks)
    assert_equal 200, result[:summary][:total_clicks]

    # Check top performers
    assert_kind_of Array, result[:top_performers]

    # Check recommendations
    assert_kind_of Array, result[:recommendations]
  end

  # get_priority_queue tests
  def test_get_priority_queue_returns_prioritized_tasks
    quick_wins = [
      { keyword: 'priority keyword', position: 11, impressions: 2000, opportunity_score: 150.0 }
    ]

    declining_pages = [
      { path: '/blog/declining', title: 'Declining Article', change_percent: -45.0, pageviews: 200, previous_pageviews: 400 }
    ]

    low_ctr_pages = [
      { url: '/blog/low-ctr', impressions: 3000, ctr: 1.0, missed_clicks: 120 }
    ]

    trending_queries = [
      { query: 'hot topic', recent_impressions: 800, change_percent: 200.0 }
    ]

    @mock_gsc.expect(:get_quick_wins, quick_wins, days: 30)
    @mock_ga.expect(:get_declining_pages, declining_pages, comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, low_ctr_pages, days: 30)
    @mock_gsc.expect(:get_trending_queries, trending_queries)

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue(limit: 10)

    assert_kind_of Array, result
    assert_operator result.size, :<=, 10

    # Check that results are sorted by priority
    priorities = result.map { |r| r[:priority] }
    priority_order = { 'high' => 0, 'medium' => 1, 'low' => 2 }
    sorted_priorities = priorities.sort_by { |p| priority_order[p] || 3 }
    assert_equal sorted_priorities, priorities, 'Results should be sorted by priority'
  end

  def test_get_priority_queue_limits_results
    # Create enough quick wins to generate multiple recommendations
    # But the recommendations are generated from opportunities, not directly from quick_wins count
    # Each opportunity category can generate at most 1 recommendation
    quick_wins = (1..30).map do |i|
      { keyword: "keyword #{i}", position: 12, impressions: 1000 - i, opportunity_score: 100 - i }
    end

    declining_pages = (1..5).map do |i|
      { path: "/blog/declining-#{i}", title: "Declining Article #{i}", change_percent: -40.0, pageviews: 100, previous_pageviews: 200 }
    end

    low_ctr_pages = (1..5).map do |i|
      { url: "/blog/low-ctr-#{i}", impressions: 3000, ctr: 1.0, missed_clicks: 100 + i }
    end

    trending_queries = (1..5).map do |i|
      { query: "trending topic #{i}", recent_impressions: 500 + i, change_percent: 150.0 }
    end

    @mock_gsc.expect(:get_quick_wins, quick_wins, days: 30)
    @mock_ga.expect(:get_declining_pages, declining_pages, comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, low_ctr_pages, days: 30)
    @mock_gsc.expect(:get_trending_queries, trending_queries)

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue(limit: 3)

    # The system generates 1 recommendation per category (4 total)
    # but we limit to 3
    assert_equal 3, result.size
  end

  # Recommendation generation tests
  def test_generates_quick_win_recommendation
    quick_wins = [
      { keyword: 'target keyword', position: 12.5, impressions: 3000, opportunity_score: 200.0 }
    ]

    @mock_gsc.expect(:get_quick_wins, quick_wins, days: 30)
    @mock_ga.expect(:get_declining_pages, [], comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, [], days: 30)
    @mock_gsc.expect(:get_trending_queries, [])

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue

    quick_win_rec = result.find { |r| r[:type] == 'optimize' }
    assert quick_win_rec, 'Expected a quick win recommendation'
    assert_equal 'high', quick_win_rec[:priority]
    assert quick_win_rec[:action].include?('target keyword')
    assert quick_win_rec[:reason].include?('3,000')
  end

  def test_generates_declining_content_recommendation
    declining_pages = [
      { path: '/blog/old-post', title: 'Old Post Title', change_percent: -50.0, pageviews: 100, previous_pageviews: 200 }
    ]

    @mock_gsc.expect(:get_quick_wins, [], days: 30)
    @mock_ga.expect(:get_declining_pages, declining_pages, comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, [], days: 30)
    @mock_gsc.expect(:get_trending_queries, [])

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue

    update_rec = result.find { |r| r[:type] == 'update' }
    assert update_rec, 'Expected a declining content recommendation'
    assert_equal 'high', update_rec[:priority]
    assert update_rec[:action].include?('Old Post Title')
    assert update_rec[:reason].include?('50')
  end

  def test_generates_low_ctr_recommendation
    low_ctr_pages = [
      { url: '/blog/needs-meta', impressions: 5000, ctr: 1.5, missed_clicks: 200 }
    ]

    @mock_gsc.expect(:get_quick_wins, [], days: 30)
    @mock_ga.expect(:get_declining_pages, [], comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, low_ctr_pages, days: 30)
    @mock_gsc.expect(:get_trending_queries, [])

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue

    meta_rec = result.find { |r| r[:type] == 'optimize_meta' }
    assert meta_rec, 'Expected a low CTR recommendation'
    assert_equal 'medium', meta_rec[:priority]
    assert meta_rec[:reason].include?('5,000')
    assert meta_rec[:reason].include?('200')
  end

  def test_generates_trending_topic_recommendation
    trending_queries = [
      { query: 'hot new topic', recent_impressions: 1000, change_percent: 300.0 }
    ]

    @mock_gsc.expect(:get_quick_wins, [], days: 30)
    @mock_ga.expect(:get_declining_pages, [], comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, [], days: 30)
    @mock_gsc.expect(:get_trending_queries, trending_queries)

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue

    trend_rec = result.find { |r| r[:type] == 'create_new' }
    assert trend_rec, 'Expected a trending topic recommendation'
    assert_equal 'medium', trend_rec[:priority]
    assert trend_rec[:action].include?('hot new topic')
    assert trend_rec[:reason].include?('300')
  end

  # Edge case tests
  def test_handles_all_services_nil
    aggregator = AgentSeo::DataAggregator.new(ga: nil, gsc: nil, dfs: nil)

    # Should not raise, just return empty/nil data
    result = aggregator.identify_content_opportunities
    assert_kind_of Hash, result
    assert_empty result[:quick_wins]
    assert_empty result[:declining_content]
  end

  def test_handles_empty_opportunities
    @mock_gsc.expect(:get_quick_wins, [], days: 30)
    @mock_ga.expect(:get_declining_pages, [], comparison_days: 30, threshold_percent: -20.0)
    @mock_gsc.expect(:get_low_ctr_pages, [], days: 30)
    @mock_gsc.expect(:get_trending_queries, [])

    aggregator = AgentSeo::DataAggregator.new(ga: @mock_ga, gsc: @mock_gsc, dfs: nil)
    result = aggregator.get_priority_queue

    # Should return empty array, not nil or raise
    assert_kind_of Array, result
    assert_empty result
  end
end
