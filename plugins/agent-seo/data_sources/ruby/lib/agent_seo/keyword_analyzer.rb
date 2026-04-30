# frozen_string_literal: true

module AgentSeo
  # Keyword Analyzer
  # Calculates keyword density, analyzes distribution, and identifies keyword usage
  # patterns within content.
  class KeywordAnalyzer
    STOP_WORDS = %w[
      a an and are as at be by for from has he in is it its of on that the
      to was will with you your this their but or not can have all when there
      been if more so about what which who would could
    ].freeze

    attr_reader :stop_words

    def initialize
      @stop_words = STOP_WORDS.to_set
    end

    # Comprehensive keyword analysis
    #
    # @param content [String] Article content to analyze
    # @param primary_keyword [String] Main target keyword
    # @param secondary_keywords [Array<String>] List of secondary keywords
    # @param target_density [Float] Target keyword density percentage (default 1.5%)
    # @return [Hash] Density metrics, distribution map, and recommendations
    def analyze(content, primary_keyword, secondary_keywords: [], target_density: 1.5)
      # Pre-compute once to avoid repeated scans
      content_lower = content.downcase.freeze
      words = content.split
      word_count = words.length
      sections = extract_sections(content)

      # Pre-compute primary keyword in lowercase
      primary_keyword_lower = primary_keyword.downcase.freeze

      # Analyze primary keyword (pass pre-computed lowercase values)
      primary_analysis = analyze_keyword(
        content_lower, primary_keyword_lower, word_count, sections, target_density
      )

      # Analyze secondary keywords
      secondary_analysis = secondary_keywords.map do |keyword|
        keyword_lower = keyword.downcase.freeze
        analyze_keyword(content_lower, keyword_lower, word_count, sections, target_density * 0.5)
      end

      # Detect keyword stuffing (pass original content for paragraph splitting, plus pre-computed lowercase)
      stuffing_risk = detect_keyword_stuffing(
        content, content_lower, primary_keyword_lower, primary_analysis[:density]
      )

      {
        word_count: word_count,
        primary_keyword: { keyword: primary_keyword }.merge(primary_analysis),
        secondary_keywords: secondary_analysis,
        keyword_stuffing: stuffing_risk,
        recommendations: generate_recommendations(
          primary_analysis,
          secondary_analysis,
          stuffing_risk,
          target_density
        )
      }
    end

    private

    # Analyze a single keyword
    # @param content_lower [String] Pre-computed lowercase content
    # @param keyword_lower [String] Pre-computed lowercase keyword
    # @param word_count [Integer] Pre-computed word count
    # @param sections [Array<Hash>] Pre-extracted sections
    # @param target_density [Float] Target keyword density percentage
    def analyze_keyword(content_lower, keyword_lower, word_count, sections, target_density)
      # Count exact matches (values already lowercase)
      exact_count = content_lower.scan(keyword_lower).length

      # Count variations for multi-word keywords
      variation_count = 0
      keyword_words = keyword_lower.split
      if keyword_words.length > 1
        escaped_words = keyword_words.map { |w| Regexp.escape(w) }
        pattern = Regexp.new("\\b(?:#{escaped_words.join('|')})\\b", Regexp::IGNORECASE)
        matches = content_lower.scan(pattern)
        variation_count = matches.length - (exact_count * keyword_words.length)
      end

      total_count = exact_count + (keyword_words.length > 1 ? variation_count / keyword_words.length : 0)

      # Calculate density
      density = word_count.positive? ? (total_count.to_f / word_count * 100) : 0

      # Find positions (pass pre-computed lowercase values)
      positions = find_keyword_positions(content_lower, keyword_lower)

      # Check critical placements (pass pre-computed lowercase keyword)
      critical_placements = check_critical_placements(content_lower, sections, keyword_lower)

      # Distribution across sections (pass pre-computed lowercase keyword)
      section_distribution = analyze_section_distribution(sections, keyword_lower)

      {
        exact_matches: exact_count,
        total_occurrences: total_count,
        density: density.round(2),
        target_density: target_density,
        density_status: get_density_status(density, target_density),
        positions: positions,
        critical_placements: critical_placements,
        section_distribution: section_distribution
      }
    end

    # Extract sections with headers from content
    def extract_sections(content)
      sections = []
      lines = content.split("\n")
      current_section = { type: 'intro', header: '', content: '', start_pos: 0 }
      current_pos = 0

      lines.each do |line|
        h1_match = line.match(/^#\s+(.+)$/)
        h2_match = line.match(/^##\s+(.+)$/)
        h3_match = line.match(/^###\s+(.+)$/)

        if h1_match || h2_match || h3_match
          # Save previous section
          if current_section[:content].length.positive?
            current_section[:end_pos] = current_pos
            sections << current_section.dup
          end

          # Start new section
          header = if h1_match
                     h1_match[1]
                   elsif h2_match
                     h2_match[1]
                   else
                     h3_match[1]
                   end
          header_type = if h1_match
                          'h1'
                        elsif h2_match
                          'h2'
                        else
                          'h3'
                        end

          current_section = {
            type: header_type,
            header: header,
            content: '',
            start_pos: current_pos
          }
        else
          current_section[:content] += "#{line}\n"
        end

        current_pos += line.length + 1
      end

      # Add last section
      if current_section[:content].length.positive?
        current_section[:end_pos] = current_pos
        sections << current_section
      end

      sections
    end

    # Find all positions where keyword appears
    # @param content_lower [String] Pre-computed lowercase content
    # @param keyword_lower [String] Pre-computed lowercase keyword
    def find_keyword_positions(content_lower, keyword_lower)
      positions = []

      start = 0
      while (pos = content_lower.index(keyword_lower, start))
        positions << pos
        start = pos + 1
      end

      positions
    end

    # Check if keyword appears in critical locations
    # @param content_lower [String] Pre-computed lowercase content
    # @param sections [Array<Hash>] Pre-extracted sections
    # @param keyword_lower [String] Pre-computed lowercase keyword
    def check_critical_placements(content_lower, sections, keyword_lower)
      # First 100 words (content already lowercase)
      first_100 = content_lower.split.first(100).join(' ')
      in_first_100 = first_100.include?(keyword_lower)

      # Last paragraph (conclusion)
      paragraphs = content_lower.split(/\n\n+/)
      last_para = paragraphs.last || content_lower.slice(-500, 500) || ''
      in_conclusion = last_para.include?(keyword_lower)

      # H1 (first heading)
      in_h1 = sections.any? && sections.first[:header].downcase.include?(keyword_lower)

      # H2 headings
      h2_count = 0
      h2_with_keyword = 0
      sections.each do |section|
        next unless section[:type] == 'h2'

        h2_count += 1
        h2_with_keyword += 1 if section[:header].downcase.include?(keyword_lower)
      end

      {
        in_first_100_words: in_first_100,
        in_conclusion: in_conclusion,
        in_h1: in_h1,
        in_h2_headings: "#{h2_with_keyword}/#{h2_count}",
        h2_keyword_ratio: h2_count.positive? ? (h2_with_keyword.to_f / h2_count) : 0
      }
    end

    # Analyze how keyword is distributed across sections
    # @param sections [Array<Hash>] Pre-extracted sections
    # @param keyword_lower [String] Pre-computed lowercase keyword
    def analyze_section_distribution(sections, keyword_lower)
      sections.map.with_index do |section, i|
        section_text = "#{section[:header]} #{section[:content]}".downcase
        count = section_text.scan(keyword_lower).length
        word_count = section_text.split.length

        {
          section_index: i,
          section_type: section[:type],
          header: section[:header][0, 50],
          keyword_count: count,
          word_count: word_count,
          density: word_count.positive? ? (count.to_f / word_count * 100).round(2) : 0
        }
      end
    end

    # Determine if density is appropriate
    def get_density_status(actual, target)
      if actual < target * 0.5
        'too_low'
      elsif actual < target * 0.8
        'slightly_low'
      elsif actual <= target * 1.2
        'optimal'
      elsif actual <= target * 1.5
        'slightly_high'
      else
        'too_high'
      end
    end

    # Detect potential keyword stuffing
    # @param content [String] Original content (for paragraph structure)
    # @param content_lower [String] Pre-computed lowercase content
    # @param keyword_lower [String] Pre-computed lowercase keyword
    # @param density [Float] Pre-computed keyword density
    def detect_keyword_stuffing(content, content_lower, keyword_lower, density)
      risk_level = 'none'
      warnings = []

      # High density check
      if density > 3.0
        risk_level = 'high'
        warnings << "Keyword density #{density}% is very high (over 3%)"
      elsif density > 2.5
        risk_level = 'medium'
        warnings << "Keyword density #{density}% is high (over 2.5%)"
      end

      # Check for keyword clustering in paragraphs
      paragraphs = content.split(/\n\n+/)
      paragraphs.each_with_index do |para, i|
        para_lower = para.downcase
        count = para_lower.scan(keyword_lower).length
        words = para.split.length
        next unless words.positive?

        para_density = (count.to_f / words * 100)
        next unless para_density > 5

        risk_level = 'high' if risk_level == 'medium'
        warnings << "Paragraph #{i + 1} has very high keyword density (#{para_density.round(1)}%)"
      end

      # Check for unnatural repetition (keyword in consecutive sentences)
      sentences = content_lower.split(/[.!?]+/)
      consecutive = 0
      max_consecutive = 0
      sentences.each do |sentence|
        if sentence.include?(keyword_lower)
          consecutive += 1
          max_consecutive = [max_consecutive, consecutive].max
        else
          consecutive = 0
        end
      end

      if max_consecutive >= 5
        risk_level = 'high'
        warnings << "Keyword appears in #{max_consecutive} consecutive sentences"
      elsif max_consecutive >= 3
        risk_level = 'low' if risk_level == 'none'
        warnings << "Keyword appears in #{max_consecutive} consecutive sentences"
      end

      {
        risk_level: risk_level,
        warnings: warnings,
        safe: %w[none low].include?(risk_level)
      }
    end

    # Generate actionable recommendations
    def generate_recommendations(primary_analysis, secondary_analysis, stuffing_risk, target_density)
      recommendations = []

      # Primary keyword density
      status = primary_analysis[:density_status]
      case status
      when 'too_low'
        recommendations << "Primary keyword density is too low (#{primary_analysis[:density]}%). " \
                           "Target is #{target_density}%. Add #{primary_analysis[:keyword]} naturally in more paragraphs."
      when 'slightly_low'
        recommendations << "Primary keyword density is slightly low (#{primary_analysis[:density]}%). " \
                           "Consider adding a few more mentions of '#{primary_analysis[:keyword]}'."
      when 'too_high'
        recommendations << "Primary keyword density is too high (#{primary_analysis[:density]}%). " \
                           'This may trigger keyword stuffing penalties. Remove some instances or replace with variations.'
      when 'slightly_high'
        recommendations << "Primary keyword density is slightly high (#{primary_analysis[:density]}%). " \
                           'Consider using more keyword variations or synonyms.'
      end

      # Critical placements
      placements = primary_analysis[:critical_placements]
      unless placements[:in_first_100_words]
        recommendations << 'Primary keyword missing from first 100 words - add it to the introduction'
      end
      recommendations << 'Primary keyword missing from H1 headline - include it in the title' unless placements[:in_h1]

      if placements[:h2_keyword_ratio] < 0.33
        recommendations << "Primary keyword appears in only #{placements[:in_h2_headings]} H2 headings. " \
                           'Aim for 2-3 H2s with keyword variations.'
      end

      unless placements[:in_conclusion]
        recommendations << 'Consider mentioning primary keyword in the conclusion for better optimization'
      end

      # Keyword stuffing
      unless stuffing_risk[:safe]
        recommendations << "KEYWORD STUFFING RISK: #{stuffing_risk[:risk_level].upcase} - " \
                           "#{stuffing_risk[:warnings].join('; ')}"
      end

      # Secondary keywords
      secondary_analysis.each do |analysis|
        if analysis[:total_occurrences].zero?
          recommendations << "Secondary keyword '#{analysis[:keyword]}' not found in content - consider adding it"
        end
      end

      recommendations
    end
  end
end
