# frozen_string_literal: true

module AgentSeo
  # Read-only formatting audit retained behind the legacy ContentScrubber name.
  #
  # The audit reports invisible Unicode format controls and em dashes that may
  # deserve editorial review. It deliberately preserves the source text and
  # never removes provenance, authorship disclosures, or other content.
  class ContentScrubber
    FORMAT_CONTROL_PATTERN = /\p{Cf}/.freeze
    MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze

    attr_reader :stats

    def initialize
      reset_stats
    end

    # Audit content without changing it.
    #
    # @param content [String] The text content to inspect
    # @return [Array<String, Hash>] Unchanged content and audit statistics
    def scrub(content)
      reset_stats
      @stats[:findings] = audit_findings(content)
      @stats[:format_controls_detected] = @stats[:findings].count { |finding| finding[:kind] == 'format_control' }
      @stats[:emdashes_detected] = @stats[:findings].count { |finding| finding[:kind] == 'em_dash' }
      [content.dup, @stats.dup]
    end

    # Compatibility helper that returns the original content after auditing it.
    def self.scrub_content(content, verbose: false)
      audited_content, stats = new.scrub(content)
      print_stats(stats) if verbose
      audited_content
    end

    # Audit a file without writing to it. output_path is rejected so older
    # callers cannot mistake this compatibility API for a transformation step.
    def self.scrub_file(file_path, output_path: nil, verbose: false)
      raise ArgumentError, 'formatting audit is read-only; output_path is not supported' if output_path

      validate_file_path!(file_path)
      content = File.read(file_path, encoding: 'UTF-8')
      _audited_content, stats = new.scrub(content)
      print_stats(stats) if verbose
      stats
    end

    def self.report_lines(stats)
      summary_lines(stats) + stats[:findings].map { |finding| finding_line(finding) }
    end

    def self.summary_lines(stats)
      [
        'Formatting Audit Complete:',
        "  - Format-control characters detected: #{stats[:format_controls_detected]}",
        "  - Em dashes detected: #{stats[:emdashes_detected]}",
        '  - Content changed: no'
      ]
    end
    private_class_method :summary_lines

    def self.finding_line(finding)
      format('  - %<codepoint>s %<kind>s at line %<line>d, column %<column>d', finding)
    end
    private_class_method :finding_line

    def self.print_stats(stats)
      puts report_lines(stats)
    end
    private_class_method :print_stats

    private

    def audit_findings(content)
      content.each_line.with_index(1).flat_map do |line, line_number|
        findings_for_line(line, line_number)
      end
    end

    def findings_for_line(line, line_number)
      line.each_char.with_index(1).filter_map do |character, column_number|
        kind = finding_kind(character)
        next unless kind

        { kind: kind, codepoint: format('U+%04X', character.ord), line: line_number, column: column_number }
      end
    end

    def finding_kind(character)
      if FORMAT_CONTROL_PATTERN.match?(character)
        'format_control'
      elsif character == '—'
        'em_dash'
      end
    end

    def reset_stats
      @stats = {
        format_controls_detected: 0,
        emdashes_detected: 0,
        findings: [],
        content_changed: false
      }
    end

    def self.validate_file_path!(file_path)
      stat = File.lstat(file_path)
      raise ArgumentError, 'formatting audit refuses symlinks' if stat.symlink?
      raise ArgumentError, 'formatting audit requires a regular file' unless stat.file?
      return if MARKDOWN_EXTENSIONS.include?(File.extname(file_path).downcase)

      raise ArgumentError, 'formatting audit accepts only .md or .markdown files'
    end
    private_class_method :validate_file_path!
  end
end
