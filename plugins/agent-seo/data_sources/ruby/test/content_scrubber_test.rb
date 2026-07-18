# frozen_string_literal: true

require_relative 'test_helper'
require 'tempfile'

# Exercises the read-only Ruby formatting audit contract.
class ContentScrubberTest < Minitest::Test
  def setup
    @scrubber = AgentSeo::ContentScrubber.new
  end

  def test_audit_returns_unchanged_content_and_stats
    source = "Hello\u200Bworld—still here"
    audited, stats = @scrubber.scrub(source)

    assert_equal source, audited
    refute_same source, audited
    assert_equal 1, stats[:format_controls_detected]
    assert_equal 1, stats[:emdashes_detected]
    assert_equal false, stats[:content_changed]
  end

  def test_audit_counts_multiple_format_controls_without_removing_them
    source = "\uFEFFHello\u200Bworld\u2060\u0890\u{110BD}"
    audited, stats = @scrubber.scrub(source)

    assert_equal source, audited
    assert_equal 5, stats[:format_controls_detected]
  end

  def test_audit_reports_unicode_character_locations
    source = "éclair\u200B—ok\nnext\u0890line"
    _audited, stats = @scrubber.scrub(source)

    assert_equal [
      { kind: 'format_control', codepoint: 'U+200B', line: 1, column: 7 },
      { kind: 'em_dash', codepoint: 'U+2014', line: 1, column: 8 },
      { kind: 'format_control', codepoint: 'U+0890', line: 2, column: 5 }
    ], stats[:findings]
  end

  def test_audit_preserves_unicode_text
    source = "こんにちは世界\u200B日本語テスト"
    audited, stats = @scrubber.scrub(source)

    assert_equal source, audited
    assert_equal 1, stats[:format_controls_detected]
  end

  def test_clean_content_reports_zero_findings
    source = 'This is ordinary text with a regular hyphen.'
    audited, stats = @scrubber.scrub(source)

    assert_equal source, audited
    assert_equal 0, stats[:format_controls_detected]
    assert_equal 0, stats[:emdashes_detected]
  end

  def test_scrub_content_compatibility_helper_is_read_only
    source = "Keep\u200Bthis—unchanged"
    assert_equal source, AgentSeo::ContentScrubber.scrub_content(source)
  end

  def test_scrub_file_does_not_modify_source
    Tempfile.create(['agent-seo-formatting-audit', '.md']) do |file|
      source = "Keep\u200Bthis—unchanged"
      file.write(source)
      file.flush

      stats = AgentSeo::ContentScrubber.scrub_file(file.path)

      assert_equal source, File.read(file.path, encoding: 'UTF-8')
      assert_equal 1, stats[:format_controls_detected]
      assert_equal 1, stats[:emdashes_detected]
    end
  end

  def test_scrub_file_rejects_output_path
    Tempfile.create(['agent-seo-formatting-audit', '.md']) do |file|
      error = assert_raises(ArgumentError) do
        AgentSeo::ContentScrubber.scrub_file(file.path, output_path: 'cleaned.md')
      end

      assert_includes error.message, 'read-only'
    end
  end

  def test_scrub_file_rejects_non_markdown_input
    Tempfile.create(['agent-seo-formatting-audit', '.txt']) do |file|
      error = assert_raises(ArgumentError) { AgentSeo::ContentScrubber.scrub_file(file.path) }
      assert_includes error.message, 'only .md or .markdown'
    end
  end

  def test_scrub_file_rejects_symlink
    Tempfile.create(['agent-seo-formatting-audit', '.md']) do |file|
      link_path = "#{file.path}.md"
      File.symlink(file.path, link_path)

      error = assert_raises(ArgumentError) { AgentSeo::ContentScrubber.scrub_file(link_path) }
      assert_includes error.message, 'symlink'
    ensure
      File.unlink(link_path) if link_path && File.symlink?(link_path)
    end
  end
end
