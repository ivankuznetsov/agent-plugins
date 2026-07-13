# frozen_string_literal: true

require_relative 'test_helper'

class ReadabilityScorerTest < Minitest::Test
  include TestHelpers

  def setup
    @scorer = AgentSeo::ReadabilityScorer.new
  end

  # Basic analysis tests
  def test_analyze_returns_overall_score
    result = @scorer.analyze(sample_good_content)
    assert_includes 0..100, result[:overall_score]
  end

  def test_analyze_returns_grade
    result = @scorer.analyze(sample_good_content)
    assert_match(/\A[A-F] \(/, result[:grade])
  end

  def test_analyze_returns_reading_level
    result = @scorer.analyze(sample_good_content)
    assert result.key?(:reading_level)
    assert_kind_of Numeric, result[:reading_level]
  end

  def test_analyze_returns_readability_metrics
    result = @scorer.analyze(sample_good_content)
    metrics = result[:readability_metrics]
    assert metrics.key?(:flesch_reading_ease)
    assert metrics.key?(:flesch_kincaid_grade)
    assert metrics.key?(:gunning_fog)
    assert metrics.key?(:syllable_count)
    assert metrics.key?(:sentence_count)
  end

  def test_analyze_returns_structure_analysis
    result = @scorer.analyze(sample_good_content)
    structure = result[:structure_analysis]
    assert structure.key?(:total_sentences)
    assert structure.key?(:avg_sentence_length)
    assert structure.key?(:total_paragraphs)
    assert structure.key?(:total_words)
  end

  def test_analyze_returns_complexity_analysis
    result = @scorer.analyze(sample_good_content)
    complexity = result[:complexity_analysis]
    assert complexity.key?(:transition_word_count)
    assert complexity.key?(:passive_sentence_ratio)
    assert complexity.key?(:complex_word_ratio)
  end

  def test_analyze_returns_recommendations
    result = @scorer.analyze(sample_good_content)
    assert result.key?(:recommendations)
    assert_kind_of Array, result[:recommendations]
  end

  # Empty content handling
  def test_handles_empty_content
    result = @scorer.analyze('')
    assert result.key?(:error)
  end

  def test_handles_whitespace_only_content
    result = @scorer.analyze("   \n\n   ")
    assert result.key?(:error)
  end

  # Flesch Reading Ease tests
  def test_flesch_reading_ease_in_valid_range
    result = @scorer.analyze(sample_good_content)
    flesch = result[:readability_metrics][:flesch_reading_ease]
    assert_includes 0..100, flesch
  end

  def test_simple_text_has_higher_flesch_ease
    simple_text = 'The cat sat on the mat. It was a good cat. The cat was happy.'
    complex_text = 'The feline positioned itself upon the rectangular floor covering. Its disposition appeared satisfactory.'

    simple_result = @scorer.analyze(simple_text)
    complex_result = @scorer.analyze(complex_text)

    assert_operator simple_result[:readability_metrics][:flesch_reading_ease], :>,
                    complex_result[:readability_metrics][:flesch_reading_ease]
  end

  # Grade level tests
  def test_flesch_kincaid_grade_is_positive
    result = @scorer.analyze(sample_good_content)
    grade = result[:readability_metrics][:flesch_kincaid_grade]
    assert_operator grade, :>=, 0
  end

  def test_complex_text_has_higher_grade_level
    simple_text = 'I like dogs. Dogs are fun. Dogs run fast.'
    complex_text = 'The implementation of sophisticated algorithmic methodologies facilitates comprehensive analytical frameworks.'

    simple_result = @scorer.analyze(simple_text)
    complex_result = @scorer.analyze(complex_text)

    assert_operator complex_result[:readability_metrics][:flesch_kincaid_grade], :>,
                    simple_result[:readability_metrics][:flesch_kincaid_grade]
  end

  # Sentence analysis tests
  def test_counts_sentences_correctly
    text = 'First sentence. Second sentence! Third sentence?'
    result = @scorer.analyze(text)
    assert_equal 3, result[:structure_analysis][:total_sentences]
  end

  def test_calculates_average_sentence_length
    text = 'One two three. Four five.'
    result = @scorer.analyze(text)
    # (3 + 2) / 2 = 2.5
    assert_in_delta 2.5, result[:structure_analysis][:avg_sentence_length], 0.5
  end

  def test_identifies_long_sentences
    long_sentence = 'This is a very long sentence with many many many many many many many many many many many many many many many many many many many many many many many many many many words in it.'
    result = @scorer.analyze(long_sentence)
    assert_operator result[:structure_analysis][:long_sentences], :>=, 1
  end

  # Complexity tests
  def test_detects_transition_words
    text = 'First point. However, there is another view. Additionally, we must consider more. Therefore, the conclusion is clear.'
    result = @scorer.analyze(text)
    assert_operator result[:complexity_analysis][:transition_word_count], :>=, 3
  end

  def test_detects_passive_voice
    passive_text = 'The ball was thrown by the boy. The cake was eaten. The book was read by many.'
    result = @scorer.analyze(passive_text)
    assert_operator result[:complexity_analysis][:passive_sentence_ratio], :>, 0
  end

  def test_counts_complex_words
    text = 'The implementation requires comprehensive understanding of methodological approaches.'
    result = @scorer.analyze(text)
    assert_operator result[:complexity_analysis][:complex_word_count], :>, 0
  end

  # Recommendations tests
  def test_recommends_for_complex_text
    complex_text = 'The implementation of sophisticated algorithmic methodologies facilitates comprehensive analytical frameworks. Furthermore, the systematic categorization of multidimensional parameters necessitates extraordinarily meticulous consideration of all pertinent variables.'
    result = @scorer.analyze(complex_text)
    assert_operator result[:recommendations].length, :>, 0
  end

  def test_provides_positive_feedback_for_good_content
    result = @scorer.analyze(sample_good_content)
    # Should have some recommendations or positive feedback
    assert result.key?(:recommendations)
  end

  # Status tests
  def test_returns_status_assessment
    result = @scorer.analyze(sample_good_content)
    status = result[:status]
    assert status.key?(:grade_level_status)
    assert status.key?(:ease_status)
    assert status.key?(:sentence_length_status)
    assert status.key?(:overall_assessment)
  end
end
