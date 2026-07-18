# frozen_string_literal: true

require_relative 'test_helper'
require 'digest'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Exercises the command-line formatting audit contract in a separate process.
class SeoScrubCliTest < Minitest::Test
  CLI = File.expand_path('../bin/seo-scrub', __dir__)

  def test_json_audit_reports_locations_without_mutating_file
    with_markdown_file do |path, _source|
      stdout, stderr, status = run_cli('--file', path, '--json')
      payload = JSON.parse(stdout)

      assert status.success?, stderr
      assert_empty stderr
      assert_equal false, payload.fetch('content_changed')
      assert_equal 2, payload.fetch('findings').length
      assert_equal({ 'kind' => 'format_control', 'codepoint' => 'U+200B', 'line' => 1, 'column' => 7 },
                   payload.fetch('findings').first)
    end
  end

  def test_json_audit_does_not_mutate_file
    with_markdown_file do |path, source|
      before = Digest::SHA256.file(path).hexdigest
      _stdout, _stderr, status = run_cli('--file', path, '--json')

      assert status.success?
      assert_equal before, Digest::SHA256.file(path).hexdigest
      assert_equal source, File.read(path, encoding: 'UTF-8')
    end
  end

  def test_human_audit_reports_to_stdout
    stdout, stderr, status = run_cli(stdin_data: "Keep\u0890this—unchanged")

    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, 'U+0890 format_control at line 1, column 5'
    assert_includes stdout, 'U+2014 em_dash at line 1, column 10'
    assert_includes stdout, 'Content changed: no'
  end

  def test_rejects_non_markdown_directory_symlink_and_missing_paths
    Dir.mktmpdir('agent-seo-cli-invalid') do |directory|
      invalid_inputs(directory).each { |path, message| assert_cli_rejects(path, message) }
    end
  end

  def test_output_flag_returns_stable_read_only_error
    stdout, stderr, status = run_cli('--output', 'cleaned.md', stdin_data: 'content')

    assert_equal 2, status.exitstatus
    assert_empty stdout
    assert_includes stderr, '--output was removed in Agent SEO 2.0'
  end

  private

  def assert_cli_rejects(path, message)
    stdout, stderr, status = run_cli('--file', path, '--json')
    refute status.success?, path
    assert_empty stdout
    assert_includes stderr, message
    refute_includes stderr, 'from '
  end

  def run_cli(*arguments, stdin_data: '')
    Open3.capture3(RbConfig.ruby, CLI, *arguments, stdin_data: stdin_data)
  end

  def invalid_inputs(directory)
    text_path = File.join(directory, 'article.txt')
    markdown_path = File.join(directory, 'article.md')
    link_path = File.join(directory, 'linked.md')
    File.write(text_path, 'text', encoding: 'UTF-8')
    File.write(markdown_path, 'markdown', encoding: 'UTF-8')
    File.symlink(markdown_path, link_path)
    { text_path => 'only .md or .markdown', directory => 'regular file',
      link_path => 'symlink', File.join(directory, 'missing.md') => 'No such file' }
  end

  def with_markdown_file
    Dir.mktmpdir('agent-seo-cli-test') do |directory|
      path = File.join(directory, 'article.md')
      source = "éclair\u200B—ok\n"
      File.write(path, source, encoding: 'UTF-8')
      yield path, source
    end
  end
end
