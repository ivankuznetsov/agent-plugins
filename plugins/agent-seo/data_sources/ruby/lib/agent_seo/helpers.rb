# frozen_string_literal: true

module AgentSeo
  module Helpers
    module TextUtils
      def self.extract_sentences(text)
        text.split(/[.!?]+/).map(&:strip).reject(&:empty?)
      end

      def self.word_count(text)
        text.split.length
      end
    end

    module MarkdownParser
      Header = Struct.new(:level, :text, :line_number)

      def self.extract_headers(content)
        headers = []
        content.each_line.with_index do |line, i|
          if (match = line.match(/^(#+)\s+(.+)$/))
            headers << Header.new(match[1].length, match[2].strip, i)
          end
        end
        headers
      end
    end

    module Scoring
      def self.letter_grade(score)
        case score
        when 90..100 then 'A (Excellent)'
        when 80...90 then 'B (Good)'
        when 70...80 then 'C (Average)'
        when 60...70 then 'D (Needs Work)'
        else 'F (Poor)'
        end
      end
    end
  end
end
