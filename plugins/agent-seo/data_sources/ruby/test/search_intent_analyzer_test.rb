# frozen_string_literal: true

require_relative 'test_helper'

class SearchIntentAnalyzerTest < Minitest::Test
  def setup
    @analyzer = AgentSeo::SearchIntentAnalyzer.new
  end

  # Basic analysis tests
  def test_analyze_returns_primary_intent
    result = @analyzer.analyze('how to start a podcast')
    assert result.key?(:primary_intent)
    assert_includes %w[informational navigational transactional commercial], result[:primary_intent]
  end

  def test_analyze_returns_confidence_scores
    result = @analyzer.analyze('best podcast microphone')
    assert result.key?(:confidence)
    %w[informational navigational transactional commercial].each do |intent|
      assert result[:confidence].key?(intent)
      assert_kind_of Numeric, result[:confidence][intent]
    end
  end

  def test_analyze_returns_recommendations
    result = @analyzer.analyze('podcast equipment review')
    assert result.key?(:recommendations)
    assert_kind_of Array, result[:recommendations]
  end

  # Informational intent tests
  def test_classifies_how_to_as_informational
    result = @analyzer.analyze('how to record a podcast')
    assert_equal 'informational', result[:primary_intent]
  end

  def test_classifies_what_is_as_informational
    result = @analyzer.analyze('what is podcasting')
    assert_equal 'informational', result[:primary_intent]
  end

  def test_classifies_why_as_informational
    result = @analyzer.analyze('why start a podcast')
    assert_equal 'informational', result[:primary_intent]
  end

  def test_classifies_guide_as_informational
    result = @analyzer.analyze('podcast editing guide')
    assert_equal 'informational', result[:primary_intent]
  end

  def test_classifies_tutorial_as_informational
    result = @analyzer.analyze('podcast tutorial for beginners')
    assert_equal 'informational', result[:primary_intent]
  end

  # Transactional intent tests
  def test_classifies_buy_as_transactional
    result = @analyzer.analyze('buy podcast microphone')
    assert_equal 'transactional', result[:primary_intent]
  end

  def test_classifies_pricing_as_transactional
    result = @analyzer.analyze('podcast hosting pricing')
    assert_equal 'transactional', result[:primary_intent]
  end

  def test_classifies_discount_as_transactional
    result = @analyzer.analyze('podcast software discount')
    assert_equal 'transactional', result[:primary_intent]
  end

  def test_classifies_free_trial_as_transactional
    result = @analyzer.analyze('podcast hosting free trial')
    assert_equal 'transactional', result[:primary_intent]
  end

  # Commercial investigation intent tests
  def test_classifies_best_as_commercial
    result = @analyzer.analyze('best podcast hosting')
    assert_equal 'commercial', result[:primary_intent]
  end

  def test_classifies_vs_as_commercial
    result = @analyzer.analyze('anchor vs buzzsprout')
    assert_equal 'commercial', result[:primary_intent]
  end

  def test_classifies_comparison_as_commercial
    result = @analyzer.analyze('podcast software comparison')
    assert_equal 'commercial', result[:primary_intent]
  end

  def test_classifies_review_as_commercial
    result = @analyzer.analyze('riverside fm review')
    assert_equal 'commercial', result[:primary_intent]
  end

  def test_classifies_alternatives_as_commercial
    result = @analyzer.analyze('anchor alternatives')
    assert_equal 'commercial', result[:primary_intent]
  end

  # Navigational intent tests
  def test_classifies_login_as_navigational
    result = @analyzer.analyze('spotify login')
    assert_equal 'navigational', result[:primary_intent]
  end

  def test_classifies_website_as_navigational
    result = @analyzer.analyze('anchor website')
    assert_equal 'navigational', result[:primary_intent]
  end

  def test_classifies_app_as_navigational
    result = @analyzer.analyze('spotify podcast app')
    assert_equal 'navigational', result[:primary_intent]
  end

  # SERP features influence
  def test_serp_features_influence_classification
    result_with_shopping = @analyzer.analyze(
      'podcast microphone',
      serp_features: ['shopping_results', 'product_ads']
    )
    result_without = @analyzer.analyze('podcast microphone')

    # Shopping SERP features should increase transactional confidence
    assert_operator result_with_shopping[:confidence]['transactional'], :>=,
                    result_without[:confidence]['transactional']
  end

  def test_featured_snippet_influences_informational
    result_with_snippet = @analyzer.analyze(
      'what is RSS feed',
      serp_features: ['featured_snippet', 'knowledge_panel']
    )
    assert_equal 'informational', result_with_snippet[:primary_intent]
  end

  # Secondary intent tests
  def test_detects_secondary_intent
    # "best podcast equipment guide" could be both commercial and informational
    result = @analyzer.analyze('best podcast equipment guide')
    # Should have either commercial or informational as primary/secondary
    intents = [result[:primary_intent], result[:secondary_intent]].compact
    assert(intents.include?('commercial') || intents.include?('informational'))
  end

  # Edge cases
  def test_handles_empty_keyword
    result = @analyzer.analyze('')
    assert result.key?(:primary_intent)
  end

  def test_handles_ambiguous_keywords
    result = @analyzer.analyze('podcast')
    assert result.key?(:primary_intent)
    # Single word should still classify
    assert_includes %w[informational navigational transactional commercial], result[:primary_intent]
  end

  def test_handles_very_long_keywords
    long_keyword = 'how to start a podcast for beginners with no experience and make money'
    result = @analyzer.analyze(long_keyword)
    assert result.key?(:primary_intent)
  end

  # Signals detected tests
  def test_returns_detected_signals
    result = @analyzer.analyze('how to start a podcast')
    assert result.key?(:signals_detected)
  end

  # Confidence sum test
  def test_confidence_scores_sum_to_100
    result = @analyzer.analyze('podcast hosting comparison')
    total = result[:confidence].values.sum
    assert_in_delta 100.0, total, 1.0
  end
end
