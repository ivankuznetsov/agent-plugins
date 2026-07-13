# frozen_string_literal: true

require_relative 'test_helper'

class ContentScrubberTest < Minitest::Test
  def setup
    @scrubber = AgentSeo::ContentScrubber.new
  end

  # Basic scrubbing tests
  def test_scrub_returns_cleaned_content_and_stats
    content, stats = @scrubber.scrub('Hello world')
    assert_kind_of String, content
    assert_kind_of Hash, stats
  end

  def test_scrub_returns_stats_with_counts
    _content, stats = @scrubber.scrub('Hello world')
    assert stats.key?(:unicode_removed)
    assert stats.key?(:emdashes_replaced)
    assert stats.key?(:format_control_removed)
  end

  # Zero-width space removal
  def test_removes_zero_width_spaces
    content_with_zws = "Hello\u200Bworld"
    cleaned, _stats = @scrubber.scrub(content_with_zws)
    refute_includes cleaned, "\u200B"
    # Note: When ZWS is between words, it's replaced with a space (not removed)
    # so unicode_removed may be 0. The key assertion is that ZWS is gone.
  end

  def test_replaces_zws_between_words_with_space
    content_with_zws = "Hello\u200Bworld"
    cleaned, _stats = @scrubber.scrub(content_with_zws)
    assert_equal 'Hello world', cleaned
  end

  # BOM removal
  def test_removes_byte_order_mark
    content_with_bom = "\uFEFFHello world"
    cleaned, stats = @scrubber.scrub(content_with_bom)
    refute_includes cleaned, "\uFEFF"
    assert_operator stats[:unicode_removed], :>, 0
  end

  # Other invisible characters
  def test_removes_zero_width_non_joiner
    content = "Hello\u200Cworld"
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, "\u200C"
  end

  def test_removes_word_joiner
    content = "Hello\u2060world"
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, "\u2060"
  end

  def test_removes_soft_hyphen
    content = "Hello\u00ADworld"
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, "\u00AD"
  end

  def test_removes_narrow_no_break_space
    content = "Hello\u202Fworld"
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, "\u202F"
  end

  # Em-dash replacement tests
  def test_replaces_em_dashes
    content = 'This is important—it really matters.'
    cleaned, stats = @scrubber.scrub(content)
    refute_includes cleaned, '—'
    assert_operator stats[:emdashes_replaced], :>, 0
  end

  def test_em_dash_replaced_with_comma_for_aside
    content = 'The tool—which is free—works well.'
    cleaned, _stats = @scrubber.scrub(content)
    # Should use commas for parenthetical aside
    assert_includes cleaned, ','
  end

  def test_em_dash_replaced_appropriately_for_independent_clauses
    content = 'I love podcasting—it brings me joy.'
    cleaned, _stats = @scrubber.scrub(content)
    # Should have some punctuation instead of em-dash
    refute_includes cleaned, '—'
  end

  # Whitespace cleanup
  def test_removes_double_spaces
    content = 'Hello  world  test'
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, '  '
  end

  def test_normalizes_multiple_newlines
    content = "Hello\n\n\n\n\nworld"
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, "\n\n\n"
  end

  def test_fixes_space_before_punctuation
    content = 'Hello , world .'
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, ' ,'
    refute_includes cleaned, ' .'
  end

  # Class method tests
  def test_scrub_content_class_method
    content_with_zws = "Hello\u200Bworld"
    cleaned = AgentSeo::ContentScrubber.scrub_content(content_with_zws)
    assert_kind_of String, cleaned
    refute_includes cleaned, "\u200B"
  end

  # Edge cases
  def test_handles_empty_content
    cleaned, stats = @scrubber.scrub('')
    assert_equal '', cleaned
    assert_equal 0, stats[:unicode_removed]
  end

  def test_handles_content_without_watermarks
    clean_content = 'This is perfectly normal text without any issues.'
    cleaned, stats = @scrubber.scrub(clean_content)
    assert_equal clean_content, cleaned
    assert_equal 0, stats[:unicode_removed]
    assert_equal 0, stats[:emdashes_replaced]
  end

  def test_preserves_regular_dashes
    content = 'Self-driven and well-known are hyphenated words.'
    cleaned, _stats = @scrubber.scrub(content)
    assert_includes cleaned, '-'
    assert_includes cleaned, 'Self-driven'
  end

  def test_handles_multiple_watermark_types
    content = "\uFEFFHello\u200Bworld—test\u2060here"
    cleaned, stats = @scrubber.scrub(content)
    refute_includes cleaned, "\uFEFF"
    refute_includes cleaned, "\u200B"
    refute_includes cleaned, '—'
    refute_includes cleaned, "\u2060"
    assert_operator stats[:unicode_removed] + stats[:emdashes_replaced], :>, 0
  end

  def test_handles_unicode_text
    content = "こんにちは世界\u200B日本語テスト"
    cleaned, _stats = @scrubber.scrub(content)
    refute_includes cleaned, "\u200B"
    assert_includes cleaned, 'こんにちは'
  end

  # Real-world example test
  def test_scrubs_realistic_ai_content
    ai_content = <<~CONTENT
      \uFEFFThe podcast\u200B landscape has witnessed\u200C a pivotal transformation—showcasing\u2060 the remarkable interplay between content creators and their audiences.
    CONTENT

    cleaned, stats = @scrubber.scrub(ai_content)

    refute_includes cleaned, "\uFEFF"
    refute_includes cleaned, "\u200B"
    refute_includes cleaned, "\u200C"
    refute_includes cleaned, "\u2060"
    refute_includes cleaned, '—'
    assert_operator stats[:unicode_removed] + stats[:emdashes_replaced], :>, 0
  end
end
