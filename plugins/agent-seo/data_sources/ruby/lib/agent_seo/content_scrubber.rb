# frozen_string_literal: true

module AgentSeo
  # Content Scrubber
  # Removes AI-generated content watermarks and telltale signs including:
  # - Invisible Unicode characters (zero-width spaces, format-control characters, etc.)
  # - Em-dashes replaced with contextually appropriate punctuation
  #
  # This module ensures content appears naturally human-written.
  class ContentScrubber
    # Specific Unicode characters to remove
    WATERMARK_CHARS = [
      "\u200B", # Zero-width space
      "\uFEFF", # Byte Order Mark (BOM)
      "\u200C", # Zero-width non-joiner
      "\u2060", # Word joiner
      "\u00AD", # Soft hyphen
      "\u202F"  # Narrow no-break space
    ].freeze

    # Regex pattern for Unicode Category Cf (format-control) characters
    # Covers: soft hyphen, Arabic marks, Syriac abbreviation, Mongolian vowel separator,
    # BOM, zero-width/directional marks, word joiner, invisible operators, directional isolates
    FORMAT_CONTROL_PATTERN = /[\u00AD\u061C\u06DD\u070F\u08E2\u180E\uFEFF\u0600-\u0605\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F]/.freeze

    attr_reader :stats

    def initialize
      reset_stats
    end

    # Scrub content of all AI watermarks and telltale signs
    #
    # @param content [String] The text content to scrub
    # @return [Array<String, Hash>] Tuple of (cleaned_content, statistics_dict)
    def scrub(content)
      reset_stats

      # Step 1: Remove specific watermark characters
      content = remove_watermark_chars(content)

      # Step 2: Remove all Unicode format-control characters (Category Cf)
      content = remove_format_control_chars(content)

      # Step 3: Replace em-dashes with contextually appropriate punctuation
      content = replace_emdashes(content)

      # Step 4: Clean up any double spaces created by removals
      content = clean_whitespace(content)

      [content, @stats.dup]
    end

    # Convenience method to scrub and return just the content
    #
    # @param content [String] The text to scrub
    # @param verbose [Boolean] If true, print statistics
    # @return [String] Cleaned content
    def self.scrub_content(content, verbose: false)
      scrubber = new
      cleaned_content, stats = scrubber.scrub(content)

      if verbose
        puts 'Content Scrubbing Complete:'
        puts "  - Unicode watermarks removed: #{stats[:unicode_removed]}"
        puts "  - Format-control chars removed: #{stats[:format_control_removed]}"
        puts "  - Em-dashes replaced: #{stats[:emdashes_replaced]}"
      end

      cleaned_content
    end

    # Scrub a file and optionally save to a new location
    #
    # @param file_path [String] Path to file to scrub
    # @param output_path [String] Path to save cleaned content (if nil, overwrites original)
    # @param verbose [Boolean] If true, print statistics
    def self.scrub_file(file_path, output_path: nil, verbose: false)
      content = File.read(file_path, encoding: 'UTF-8')
      cleaned_content = scrub_content(content, verbose: verbose)

      output = output_path || file_path
      File.write(output, cleaned_content, encoding: 'UTF-8')

      puts "Scrubbed content saved to: #{output}" if verbose
    end

    private

    def reset_stats
      @stats = {
        unicode_removed: 0,
        emdashes_replaced: 0,
        format_control_removed: 0
      }
    end

    # Remove specific invisible Unicode watermark characters
    def remove_watermark_chars(content)
      original_len = content.length

      WATERMARK_CHARS.each do |char|
        if char == "\u200B"
          # Replace zero-width space between alphanumeric chars with regular space
          content = content.gsub(/(\w)\u200B(\w)/, '\1 \2')
          # Remove any remaining zero-width spaces
          content = content.gsub(char, '')
        else
          content = content.gsub(char, '')
        end
      end

      @stats[:unicode_removed] = original_len - content.length
      content
    end

    # Remove all Unicode Category Cf (format-control) characters
    # Optimized to use regex instead of character-by-character iteration
    def remove_format_control_chars(content)
      original_len = content.length
      cleaned = content.gsub(FORMAT_CONTROL_PATTERN, '')
      @stats[:format_control_removed] = original_len - cleaned.length
      cleaned
    end

    # Replace em-dashes with contextually appropriate punctuation
    def replace_emdashes(content)
      # Find all em-dashes with surrounding context
      content.gsub(/([^-]{0,100})—([^-]{0,100})/) do
        before = ::Regexp.last_match(1)
        after = ::Regexp.last_match(2)

        replacement = determine_emdash_replacement(before, after)
        @stats[:emdashes_replaced] += 1

        "#{before}#{replacement}#{after}"
      end
    end

    # Determine the best punctuation to replace an em-dash
    #
    # @param before [String] Text before the em-dash
    # @param after [String] Text after the em-dash
    # @return [String] Replacement punctuation string
    def determine_emdash_replacement(before, after)
      before_context = before&.slice(-50, 50)&.strip || ''
      after_context = after&.slice(0, 50)&.strip || ''

      # Check if at the end of a sentence
      return '' if after_context.match?(/\A[.!?]/)

      # Check if it's an attribution or citation
      attribution_patterns = [
        /\b(said|wrote|noted|according to|via)\s*\z/i,
        /\A[A-Z][a-z]+ [A-Z]/
      ]

      attribution_patterns.each do |pattern|
        return ', ' if before_context.match?(pattern) || after_context.match?(pattern)
      end

      # Check if both sides have verbs (independent clauses)
      verb_pattern = /\b(is|are|was|were|has|have|had|do|does|did|can|could|will|would|should|may|might)\b/i
      has_verb_before = before_context.slice(-30, 30)&.match?(verb_pattern)
      has_verb_after = after_context.slice(0, 30)&.match?(verb_pattern)

      if has_verb_before && has_verb_after
        # Check if after starts with capital (stronger break)
        return '. ' if after_context.match?(/\A[A-Z]/)

        # Check for conjunctive adverbs
        conjunctive_adverbs = %w[however therefore moreover furthermore nevertheless consequently thus hence]
        after_lower = after_context.downcase
        return '; ' if conjunctive_adverbs.any? { |adv| after_lower.start_with?(adv) }

        # Independent clauses get semicolon
        return '; '
      end

      # Check if it's a list or series
      return ', ' if before_context.slice(-20, 20)&.include?(',') || after_context.slice(0, 20)&.include?(',')

      # Check for parenthetical or explanatory content
      return ', ' if after_context.match?(/\A[a-z]/)

      # Short after content might be an aside
      return ', ' if after_context.length < 30

      # Default: Use comma
      ', '
    end

    # Clean up multiple spaces and normalize whitespace
    def clean_whitespace(content)
      # Replace multiple spaces with single space
      content = content.gsub(/ {2,}/, ' ')

      # Fix spacing around punctuation
      content = content.gsub(/\s+([.,;:!?])/, '\1')
      content = content.gsub(/([.,;:!?])([A-Za-z])/, '\1 \2')

      # Clean up line breaks
      content = content.gsub(/\n{3,}/, "\n\n")

      content
    end
  end
end
