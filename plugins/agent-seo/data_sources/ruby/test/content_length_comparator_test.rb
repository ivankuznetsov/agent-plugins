# frozen_string_literal: true

require_relative 'test_helper'

class ContentLengthComparatorTest < Minitest::Test
  def setup
    @comparator = AgentSeo::ContentLengthComparator.new
  end

  # Basic analysis tests
  def test_analyze_without_serp_results_returns_error
    result = @comparator.analyze('test keyword')
    assert result.key?(:error)
    assert_match(/No SERP results/i, result[:error])
  end

  def test_analyze_with_empty_serp_returns_error
    result = @comparator.analyze('test keyword', serp_results: [])
    assert result.key?(:error)
  end

  # Statistics calculation tests (using mock data)
  def test_calculates_statistics_from_word_counts
    # calculate_statistics expects an array of integers (word counts)
    mock_data = [1500, 2000, 2500, 3000, 3500]

    stats = @comparator.send(:calculate_statistics, mock_data)

    assert_equal 1500, stats[:min]
    assert_equal 3500, stats[:max]
    assert_equal 2500, stats[:median]
    assert_in_delta 2500, stats[:mean], 100
  end

  def test_calculates_percentiles
    # calculate_statistics expects an array of integers (word counts)
    mock_data = (1..100).map { |n| n * 100 }

    stats = @comparator.send(:calculate_statistics, mock_data)

    assert stats.key?(:percentile_25)
    assert stats.key?(:percentile_75)
    assert_operator stats[:percentile_25], :<, stats[:median]
    assert_operator stats[:percentile_75], :>, stats[:median]
  end

  # Recommendation tests
  def test_recommendation_for_too_short_content
    mock_stats = {
      min: 1500,
      max: 4000,
      mean: 2500,
      median: 2400,
      percentile_25: 2000,
      percentile_75: 3000
    }

    recommendation = @comparator.send(:get_recommendation, mock_stats, 1500)
    assert_equal 'too_short', recommendation[:your_status]
  end

  def test_recommendation_for_short_content
    mock_stats = {
      min: 1500,
      max: 4000,
      mean: 2500,
      median: 2400,
      percentile_25: 2000,
      percentile_75: 3000
    }

    recommendation = @comparator.send(:get_recommendation, mock_stats, 2000)
    assert_equal 'short', recommendation[:your_status]
  end

  def test_recommendation_for_good_content
    mock_stats = {
      min: 1500,
      max: 4000,
      mean: 2500,
      median: 2400,
      percentile_25: 2000,
      percentile_75: 3000
    }

    recommendation = @comparator.send(:get_recommendation, mock_stats, 2500)
    assert_equal 'good', recommendation[:your_status]
  end

  def test_recommendation_for_optimal_content
    mock_stats = {
      min: 1500,
      max: 4000,
      mean: 2500,
      median: 2400,
      percentile_25: 2000,
      percentile_75: 3000
    }

    recommendation = @comparator.send(:get_recommendation, mock_stats, 3200)
    assert_equal 'optimal', recommendation[:your_status]
  end

  def test_recommendation_for_long_content
    mock_stats = {
      min: 1500,
      max: 4000,
      mean: 2500,
      median: 2400,
      percentile_25: 2000,
      percentile_75: 3000
    }

    recommendation = @comparator.send(:get_recommendation, mock_stats, 5000)
    assert_equal 'long', recommendation[:your_status]
  end

  def test_recommendation_includes_word_counts
    mock_stats = {
      min: 1500,
      max: 4000,
      mean: 2500,
      median: 2400,
      percentile_25: 2000,
      percentile_75: 3000
    }

    recommendation = @comparator.send(:get_recommendation, mock_stats, 2000)
    assert recommendation.key?(:recommended_min)
    assert recommendation.key?(:recommended_optimal)
    assert recommendation.key?(:recommended_max)
  end

  # Length categorization tests
  def test_categorizes_lengths_correctly
    mock_competitors = [
      { word_count: 800 },
      { word_count: 1200 },
      { word_count: 1800 },
      { word_count: 2300 },
      { word_count: 2800 },
      { word_count: 3500 }
    ]

    categories = @comparator.send(:categorize_lengths, mock_competitors)

    assert_equal 1, categories[:under_1000]
    assert_equal 1, categories[:'1000_1500']
    assert_equal 1, categories[:'1500_2000']
    assert_equal 1, categories[:'2000_2500']
    assert_equal 1, categories[:'2500_3000']
    assert_equal 1, categories[:'3000_plus']
  end

  # Competition analysis tests
  def test_analyzes_competition_correctly
    mock_competitors = [
      { word_count: 2000 },
      { word_count: 2200 },
      { word_count: 2500 },
      { word_count: 2800 },
      { word_count: 3000 }
    ]

    mock_stats = {
      min: 2000,
      max: 3000,
      median: 2500,
      percentile_75: 2800
    }

    analysis = @comparator.send(:analyze_competition, 2600, mock_competitors, mock_stats)

    assert_equal 3, analysis[:comparison][:shorter_than_you]
    assert_equal 2, analysis[:comparison][:longer_than_you]
  end

  def test_calculates_gap_to_median
    mock_competitors = [
      { word_count: 2000 },
      { word_count: 2500 },
      { word_count: 3000 }
    ]

    # analyze_competition needs percentile_75 to be set to avoid nil comparison
    mock_stats = { median: 2500, percentile_75: 2800 }

    analysis = @comparator.send(:analyze_competition, 2000, mock_competitors, mock_stats)

    assert_equal 500, analysis[:gap_to_median][:words]
  end

  # Position in range tests
  def test_position_below_all
    mock_competitors = [
      { word_count: 1500 },
      { word_count: 2000 },
      { word_count: 2500 }
    ]

    position = @comparator.send(:get_position_in_range, 1000, mock_competitors)
    assert_match(/below all/i, position)
  end

  def test_position_above_all
    mock_competitors = [
      { word_count: 1500 },
      { word_count: 2000 },
      { word_count: 2500 }
    ]

    position = @comparator.send(:get_position_in_range, 3000, mock_competitors)
    assert_match(/above all/i, position)
  end

  def test_position_between
    mock_competitors = [
      { word_count: 1500 },
      { word_count: 2000 },
      { word_count: 2500 },
      { word_count: 3000 }
    ]

    position = @comparator.send(:get_position_in_range, 2200, mock_competitors)
    assert_match(/between/i, position)
  end

  # Edge cases
  def test_handles_single_competitor
    # calculate_statistics expects an array of integers (word counts)
    mock_data = [2000]
    stats = @comparator.send(:calculate_statistics, mock_data)

    assert_equal 2000, stats[:min]
    assert_equal 2000, stats[:max]
    assert_equal 2000, stats[:median]
  end

  def test_handles_identical_word_counts
    # calculate_statistics expects an array of integers (word counts)
    mock_data = [2000, 2000, 2000]

    stats = @comparator.send(:calculate_statistics, mock_data)

    assert_equal 2000, stats[:min]
    assert_equal 2000, stats[:max]
    assert_equal 2000, stats[:median]
  end
end
