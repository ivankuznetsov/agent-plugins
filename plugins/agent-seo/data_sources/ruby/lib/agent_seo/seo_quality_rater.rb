# frozen_string_literal: true

module AgentSeo
  # SEO Quality Rater
  # Rates content quality against SEO best practices and guidelines.
  # Provides scoring (0-100) and specific recommendations for improvement.
  class SeoQualityRater
    attr_reader :guidelines

    DEFAULT_GUIDELINES = {
      min_word_count: 2000,
      optimal_word_count: 2500,
      max_word_count: 3000,
      primary_keyword_density_min: 1.0,
      primary_keyword_density_max: 2.0,
      secondary_keyword_density: 0.5,
      min_internal_links: 3,
      optimal_internal_links: 5,
      min_external_links: 2,
      optimal_external_links: 3,
      meta_title_length_min: 50,
      meta_title_length_max: 60,
      meta_description_length_min: 150,
      meta_description_length_max: 160,
      min_h2_sections: 4,
      optimal_h2_sections: 6,
      h2_with_keyword_ratio: 0.33,
      max_sentence_length: 25,
      target_reading_level_min: 8,
      target_reading_level_max: 10,
      paragraph_sentence_min: 2,
      paragraph_sentence_max: 4
    }.freeze

    # Initialize SEO Quality Rater
    #
    # @param guidelines [Hash] Custom SEO guidelines (defaults to standard best practices)
    def initialize(guidelines: nil)
      @guidelines = DEFAULT_GUIDELINES.merge(guidelines || {})
    end

    # Rate content against SEO best practices
    #
    # @param content [String] Article content
    # @param meta_title [String] Meta title tag
    # @param meta_description [String] Meta description tag
    # @param primary_keyword [String] Target primary keyword
    # @param secondary_keywords [Array<String>] Target secondary keywords
    # @param keyword_density [Float] Pre-calculated keyword density
    # @param internal_link_count [Integer] Number of internal links
    # @param external_link_count [Integer] Number of external links
    # @return [Hash] Overall score, category scores, and recommendations
    def rate(content:, meta_title: nil, meta_description: nil, primary_keyword: nil,
             secondary_keywords: nil, keyword_density: nil, internal_link_count: nil,
             external_link_count: nil)
      # Extract structure
      structure = analyze_structure(content, primary_keyword)

      # Score each category
      content_score = score_content(content, structure)
      keyword_score = score_keyword_optimization(content, structure, primary_keyword, secondary_keywords, keyword_density)
      meta_score = score_meta_elements(meta_title, meta_description, primary_keyword)
      structure_score = score_structure(structure)
      link_score = score_links(content, internal_link_count, external_link_count)
      readability_score = score_readability(content, structure)

      # Calculate overall score (weighted average)
      weights = {
        content: 0.20,
        keywords: 0.25,
        meta: 0.15,
        structure: 0.15,
        links: 0.15,
        readability: 0.10
      }

      overall_score = (
        content_score[:score] * weights[:content] +
        keyword_score[:score] * weights[:keywords] +
        meta_score[:score] * weights[:meta] +
        structure_score[:score] * weights[:structure] +
        link_score[:score] * weights[:links] +
        readability_score[:score] * weights[:readability]
      )

      # Compile all issues
      all_scores = [content_score, keyword_score, meta_score, structure_score, link_score, readability_score]
      critical_issues = all_scores.flat_map { |s| s[:critical] }
      warnings = all_scores.flat_map { |s| s[:warnings] }
      suggestions = all_scores.flat_map { |s| s[:suggestions] }

      {
        overall_score: overall_score.round(1),
        grade: get_grade(overall_score),
        category_scores: {
          content: content_score[:score],
          keyword_optimization: keyword_score[:score],
          meta_elements: meta_score[:score],
          structure: structure_score[:score],
          links: link_score[:score],
          readability: readability_score[:score]
        },
        critical_issues: critical_issues,
        warnings: warnings,
        suggestions: suggestions,
        publishing_ready: overall_score >= 80 && critical_issues.empty?,
        details: {
          word_count: structure[:word_count],
          h2_count: structure[:h2_count],
          has_h1: structure[:has_h1],
          keyword_in_h1: structure[:keyword_in_h1],
          keyword_in_first_100: structure[:keyword_in_first_100]
        }
      }
    end

    private

    # Analyze content structure
    def analyze_structure(content, primary_keyword)
      headers = Helpers::MarkdownParser.extract_headers(content)

      h1_count = 0
      h2_count = 0
      h3_count = 0
      h1_text = ''
      h2_texts = []
      h3_texts = []

      headers.each do |header|
        case header.level
        when 1
          h1_count += 1
          h1_text = header.text if h1_text.empty?
        when 2
          h2_count += 1
          h2_texts << header.text
        when 3
          h3_count += 1
          h3_texts << header.text
        end
      end

      word_count = content.split.length
      paragraphs = content.split(/\n\n+/).reject { |p| p.strip.empty? || p.strip.start_with?('#') }
      avg_paragraph_length = paragraphs.empty? ? 0 : paragraphs.sum { |p| p.split.length } / paragraphs.length

      # Keyword checks
      keyword_in_h1 = false
      keyword_in_first_100 = false
      h2_with_keyword = 0

      if primary_keyword
        keyword_lower = primary_keyword.downcase
        keyword_in_h1 = h1_text.downcase.include?(keyword_lower)
        first_100_words = content.split.first(100).join(' ').downcase
        keyword_in_first_100 = first_100_words.include?(keyword_lower)

        h2_texts.each do |h2|
          h2_with_keyword += 1 if h2.downcase.include?(keyword_lower)
        end
      end

      {
        word_count: word_count,
        has_h1: h1_count.positive?,
        h1_count: h1_count,
        h1_text: h1_text,
        h2_count: h2_count,
        h2_texts: h2_texts,
        h3_count: h3_count,
        paragraph_count: paragraphs.length,
        avg_paragraph_length: avg_paragraph_length,
        keyword_in_h1: keyword_in_h1,
        keyword_in_first_100: keyword_in_first_100,
        h2_with_keyword: h2_with_keyword
      }
    end

    # Score content length and quality
    def score_content(content, structure)
      score = 100
      critical = []
      warnings = []
      suggestions = []

      word_count = structure[:word_count]
      min_words = @guidelines[:min_word_count]
      optimal_words = @guidelines[:optimal_word_count]
      max_words = @guidelines[:max_word_count]

      if word_count < min_words
        score -= 30
        critical << "Content is too short (#{word_count} words). Minimum is #{min_words} words."
      elsif word_count < optimal_words
        score -= 10
        warnings << "Content could be longer (#{word_count} words). Optimal is #{optimal_words}+ words."
      elsif word_count > max_words
        score -= 5
        suggestions << "Content is quite long (#{word_count} words). Consider breaking into multiple articles if over #{max_words} words."
      end

      avg_para = structure[:avg_paragraph_length]
      if avg_para > 150
        score -= 10
        warnings << "Paragraphs are too long (avg #{avg_para.round} words). Break into 2-4 sentence paragraphs."
      elsif avg_para < 30
        score -= 5
        suggestions << "Paragraphs are very short (avg #{avg_para.round} words). Add more detail where appropriate."
      end

      { score: [score, 0].max, critical: critical, warnings: warnings, suggestions: suggestions }
    end

    # Score keyword optimization
    def score_keyword_optimization(content, structure, primary_keyword, secondary_keywords, keyword_density)
      score = 100
      critical = []
      warnings = []
      suggestions = []

      unless primary_keyword
        return { score: 50, critical: ['No primary keyword specified'], warnings: [], suggestions: [] }
      end

      # Keyword in H1
      unless structure[:keyword_in_h1]
        score -= 20
        critical << "Primary keyword '#{primary_keyword}' missing from H1 heading"
      end

      # Keyword in first 100 words
      unless structure[:keyword_in_first_100]
        score -= 15
        critical << "Primary keyword '#{primary_keyword}' missing from first 100 words"
      end

      # Keyword in H2 headings
      h2_count = structure[:h2_count]
      h2_with_kw = structure[:h2_with_keyword]
      if h2_count.positive?
        ratio = h2_with_kw.to_f / h2_count
        target_ratio = @guidelines[:h2_with_keyword_ratio]
        if ratio < target_ratio
          score -= 10
          warnings << "Keyword appears in only #{h2_with_kw}/#{h2_count} H2 headings. " \
                      "Target is at least #{(target_ratio * 100).to_i}% (2-3 H2s)"
        end
      end

      # Keyword density
      if keyword_density
        min_density = @guidelines[:primary_keyword_density_min]
        max_density = @guidelines[:primary_keyword_density_max]

        if keyword_density < min_density
          score -= 15
          warnings << "Keyword density is too low (#{keyword_density}%). Target is #{min_density}-#{max_density}%"
        elsif keyword_density > max_density * 1.5
          score -= 20
          critical << "Keyword density is too high (#{keyword_density}%). " \
                      "Risk of keyword stuffing. Target is #{min_density}-#{max_density}%"
        elsif keyword_density > max_density
          score -= 10
          warnings << "Keyword density is slightly high (#{keyword_density}%). Target is #{min_density}-#{max_density}%"
        end
      end

      # Secondary keywords
      if secondary_keywords&.any?
        content_lower = content.downcase
        missing_keywords = secondary_keywords.reject { |kw| content_lower.include?(kw.downcase) }
        if missing_keywords.any?
          score -= 5
          suggestions << "Secondary keywords not found: #{missing_keywords.join(', ')}"
        end
      end

      { score: [score, 0].max, critical: critical, warnings: warnings, suggestions: suggestions }
    end

    # Score meta title and description
    def score_meta_elements(meta_title, meta_description, primary_keyword)
      score = 100
      critical = []
      warnings = []
      suggestions = []

      # Meta title
      unless meta_title
        score -= 40
        critical << 'Meta title is missing'
      else
        title_len = meta_title.length
        min_len = @guidelines[:meta_title_length_min]
        max_len = @guidelines[:meta_title_length_max]

        if title_len < min_len
          score -= 15
          warnings << "Meta title too short (#{title_len} chars). Target is #{min_len}-#{max_len} chars."
        elsif title_len > max_len + 10
          score -= 10
          warnings << "Meta title too long (#{title_len} chars). Target is #{min_len}-#{max_len} chars."
        end

        if primary_keyword && !meta_title.downcase.include?(primary_keyword.downcase)
          score -= 15
          warnings << "Primary keyword '#{primary_keyword}' not in meta title"
        end
      end

      # Meta description
      unless meta_description
        score -= 40
        critical << 'Meta description is missing'
      else
        desc_len = meta_description.length
        min_len = @guidelines[:meta_description_length_min]
        max_len = @guidelines[:meta_description_length_max]

        if desc_len < min_len
          score -= 15
          warnings << "Meta description too short (#{desc_len} chars). Target is #{min_len}-#{max_len} chars."
        elsif desc_len > max_len + 10
          score -= 10
          warnings << "Meta description too long (#{desc_len} chars). Target is #{min_len}-#{max_len} chars."
        end

        if primary_keyword && !meta_description.downcase.include?(primary_keyword.downcase)
          score -= 10
          suggestions << "Primary keyword '#{primary_keyword}' not in meta description"
        end
      end

      { score: [score, 0].max, critical: critical, warnings: warnings, suggestions: suggestions }
    end

    # Score content structure
    def score_structure(structure)
      score = 100
      critical = []
      warnings = []
      suggestions = []

      # H1 check
      unless structure[:has_h1]
        score -= 30
        critical << 'Missing H1 heading'
      end

      if structure[:h1_count] > 1
        score -= 20
        critical << "Multiple H1 headings found (#{structure[:h1_count]}). Should only have one."
      end

      # H2 count
      h2_count = structure[:h2_count]
      min_h2 = @guidelines[:min_h2_sections]
      optimal_h2 = @guidelines[:optimal_h2_sections]

      if h2_count < min_h2
        score -= 15
        warnings << "Too few H2 sections (#{h2_count}). Add more main sections (target: #{optimal_h2})."
      elsif h2_count < optimal_h2
        score -= 5
        suggestions << "Could use more H2 sections (#{h2_count}). Optimal is #{optimal_h2} sections."
      end

      { score: [score, 0].max, critical: critical, warnings: warnings, suggestions: suggestions }
    end

    # Score internal and external linking
    def score_links(content, internal_count, external_count)
      score = 100
      critical = []
      warnings = []
      suggestions = []

      # Count links if not provided
      internal_count ||= content.scan(/\[([^\]]+)\]\((?!http)/).length
      external_count ||= content.scan(/\[([^\]]+)\]\(https?:\/\//).length

      # Internal links
      min_internal = @guidelines[:min_internal_links]
      optimal_internal = @guidelines[:optimal_internal_links]

      if internal_count < min_internal
        score -= 20
        warnings << "Too few internal links (#{internal_count}). Add #{min_internal - internal_count} more (target: #{optimal_internal})."
      elsif internal_count < optimal_internal
        score -= 5
        suggestions << "Could add more internal links (#{internal_count}). Optimal is #{optimal_internal}."
      end

      # External links
      min_external = @guidelines[:min_external_links]
      optimal_external = @guidelines[:optimal_external_links]

      if external_count < min_external
        score -= 15
        warnings << "Too few external links (#{external_count}). Add authoritative sources (target: #{optimal_external})."
      elsif external_count < optimal_external
        score -= 5
        suggestions << "Could add more external links (#{external_count}). Optimal is #{optimal_external}."
      end

      { score: [score, 0].max, critical: critical, warnings: warnings, suggestions: suggestions }
    end

    # Score readability factors
    def score_readability(content, structure)
      score = 100
      critical = []
      warnings = []
      suggestions = []

      sentences = Helpers::TextUtils.extract_sentences(content)
      sentence_lengths = sentences.map { |s| s.split.length }
      avg_sentence_length = sentence_lengths.empty? ? 0 : sentence_lengths.sum.to_f / sentence_lengths.length

      max_sentence = @guidelines[:max_sentence_length]
      if avg_sentence_length > max_sentence
        score -= 10
        warnings << "Average sentence length is #{avg_sentence_length.round(1)} words. " \
                    "Target is under #{max_sentence} words for better readability."
      end

      # Very long sentences
      long_sentences = sentence_lengths.select { |l| l > max_sentence * 1.5 }
      if long_sentences.length > sentences.length * 0.2
        score -= 10
        warnings << "#{long_sentences.length} sentences are very long (>#{(max_sentence * 1.5).to_i} words). " \
                    'Break them into shorter sentences.'
      end

      # Lists and formatting
      bullet_lists = content.scan(/^\s*[-*+]\s/m).length
      numbered_lists = content.scan(/^\s*\d+\.\s/m).length

      if (bullet_lists + numbered_lists).zero?
        score -= 5
        suggestions << 'No lists found. Use bullet points or numbered lists to improve scannability.'
      end

      { score: [score, 0].max, critical: critical, warnings: warnings, suggestions: suggestions }
    end

    # Convert score to letter grade
    def get_grade(score)
      Helpers::Scoring.letter_grade(score)
    end
  end
end
