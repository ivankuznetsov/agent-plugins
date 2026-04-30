# frozen_string_literal: true

require_relative 'test_helper'

class SeoQualityRaterTest < Minitest::Test
  include TestHelpers

  def setup
    @rater = AgentSeo::SeoQualityRater.new
  end

  # Basic rating tests
  def test_rate_returns_overall_score
    result = @rater.rate(
      content: sample_good_content,
      primary_keyword: 'start a podcast'
    )
    assert_includes 0..100, result[:overall_score]
  end

  def test_rate_returns_grade
    result = @rater.rate(
      content: sample_good_content,
      primary_keyword: 'start a podcast'
    )
    assert_match(/\A[A-F] \(/, result[:grade])
  end

  def test_rate_returns_category_scores
    result = @rater.rate(
      content: sample_good_content,
      primary_keyword: 'start a podcast'
    )
    assert result[:category_scores].key?(:content)
    assert result[:category_scores].key?(:keyword_optimization)
    assert result[:category_scores].key?(:meta_elements)
    assert result[:category_scores].key?(:structure)
    assert result[:category_scores].key?(:links)
    assert result[:category_scores].key?(:readability)
  end

  def test_rate_returns_publishing_ready_status
    result = @rater.rate(
      content: sample_good_content,
      primary_keyword: 'start a podcast'
    )
    assert [true, false].include?(result[:publishing_ready])
  end

  def test_rate_returns_content_details
    result = @rater.rate(
      content: sample_good_content,
      primary_keyword: 'start a podcast'
    )
    assert result[:details].key?(:word_count)
    assert result[:details].key?(:h2_count)
    assert result[:details].key?(:has_h1)
  end

  def test_good_content_scores_higher_than_poor_content
    good_result = @rater.rate(
      content: sample_good_content,
      meta_title: 'How to Start a Podcast: Complete 2024 Guide',
      meta_description: 'Learn how to start a podcast from scratch.',
      primary_keyword: 'start a podcast'
    )
    poor_result = @rater.rate(content: sample_poor_content, primary_keyword: 'test')
    assert_operator good_result[:overall_score], :>, poor_result[:overall_score]
  end

  # Poor content tests
  def test_flags_short_content
    result = @rater.rate(content: sample_poor_content, primary_keyword: 'test')
    assert result[:critical_issues].any? { |i| i.downcase.include?('too short') }
  end

  def test_flags_missing_meta_title
    result = @rater.rate(content: sample_poor_content, primary_keyword: 'test')
    assert result[:critical_issues].any? { |i| i.downcase.include?('meta title') }
  end

  def test_flags_missing_meta_description
    result = @rater.rate(content: sample_poor_content, primary_keyword: 'test')
    assert result[:critical_issues].any? { |i| i.downcase.include?('meta description') }
  end

  def test_poor_content_scores_low
    result = @rater.rate(content: sample_poor_content, primary_keyword: 'test')
    assert_operator result[:overall_score], :<, 65, "Poor content should score below 65"
  end

  # Meta element scoring tests
  def test_penalizes_short_meta_title
    result = @rater.rate(
      content: sample_good_content,
      meta_title: 'Short',
      meta_description: 'A proper description that meets the minimum length requirement.',
      primary_keyword: 'podcast'
    )
    assert result[:warnings].any? { |w| w.downcase.include?('meta title too short') }
  end

  def test_penalizes_long_meta_title
    result = @rater.rate(
      content: sample_good_content,
      meta_title: 'This is an extremely long meta title that definitely exceeds the recommended character limit for search engines',
      meta_description: 'A proper description.',
      primary_keyword: 'podcast'
    )
    assert result[:warnings].any? { |w| w.downcase.include?('meta title too long') }
  end

  def test_penalizes_missing_keyword_in_meta_title
    result = @rater.rate(
      content: sample_good_content,
      meta_title: 'Complete Guide to Audio Content Creation',
      meta_description: 'Learn everything about creating audio content.',
      primary_keyword: 'start a podcast'
    )
    assert result[:warnings].any? { |w| w.downcase.include?('keyword') && w.downcase.include?('meta title') }
  end

  # Keyword optimization tests
  def test_flags_missing_keyword_in_h1
    content_without_kw_in_h1 = sample_good_content.sub('# How to Start a Podcast', '# Complete Audio Guide')
    result = @rater.rate(content: content_without_kw_in_h1, primary_keyword: 'start a podcast')
    assert result[:critical_issues].any? { |i| i.downcase.include?('missing from h1') }
  end

  def test_flags_missing_keyword_in_first_100_words
    content_without_early_kw = "# Podcast Guide\n\n" + ('Lorem ipsum dolor sit amet. ' * 20) + sample_good_content
    result = @rater.rate(content: content_without_early_kw, primary_keyword: 'start a podcast')
    assert result[:critical_issues].any? { |i| i.downcase.include?('first 100 words') }
  end

  def test_flags_high_keyword_density
    result = @rater.rate(content: sample_good_content, primary_keyword: 'podcast', keyword_density: 4.0)
    assert result[:critical_issues].any? { |i| i.downcase.include?('keyword density') && i.downcase.include?('too high') }
  end

  # Structure scoring tests
  def test_flags_missing_h1
    content_without_h1 = sample_good_content.gsub(/^# .+$/, '')
    result = @rater.rate(content: content_without_h1, primary_keyword: 'podcast')
    assert result[:critical_issues].any? { |i| i.downcase.include?('missing h1') }
  end

  def test_flags_multiple_h1s
    content_with_multiple_h1 = "# First H1\n\n#{sample_good_content}"
    result = @rater.rate(content: content_with_multiple_h1, primary_keyword: 'podcast')
    assert result[:critical_issues].any? { |i| i.downcase.include?('multiple h1') }
  end

  def test_flags_too_few_h2_sections
    simple_content = "# Title\n\nJust some content without sections."
    result = @rater.rate(content: simple_content, primary_keyword: 'test')
    assert result[:warnings].any? { |w| w.downcase.include?('too few h2') }
  end

  # Link scoring tests
  def test_flags_too_few_internal_links
    result = @rater.rate(content: sample_good_content, primary_keyword: 'podcast', internal_link_count: 0)
    assert result[:warnings].any? { |w| w.downcase.include?('internal links') }
  end

  def test_flags_too_few_external_links
    result = @rater.rate(content: sample_good_content, primary_keyword: 'podcast', external_link_count: 0)
    assert result[:warnings].any? { |w| w.downcase.include?('external links') }
  end

  # Custom guidelines tests
  def test_custom_word_count_requirements
    # sample_good_content is ~200 words, so with min_word_count: 500 it should fail
    custom_rater = AgentSeo::SeoQualityRater.new(guidelines: { min_word_count: 500 })
    result = custom_rater.rate(content: sample_good_content, primary_keyword: 'podcast')
    assert result[:critical_issues].any? { |i| i.downcase.include?('too short') },
           "Content under min_word_count should be flagged as too short"
  end

  def test_custom_link_requirements
    custom_rater = AgentSeo::SeoQualityRater.new(guidelines: { min_internal_links: 10 })
    result = custom_rater.rate(content: sample_good_content, primary_keyword: 'podcast', internal_link_count: 5)
    assert result[:warnings].any? { |w| w.downcase.include?('internal links') }
  end
end
