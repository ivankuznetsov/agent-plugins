# frozen_string_literal: true

module AgentSeo
  # Readability Scorer
  # Calculates multiple readability metrics including Flesch Reading Ease,
  # Flesch-Kincaid Grade Level, and other readability indicators.
  class ReadabilityScorer
    attr_reader :target_reading_level, :target_flesch_ease, :max_avg_sentence_length, :max_paragraph_sentences

    TRANSITION_WORDS = %w[
      however moreover furthermore therefore consequently additionally
      meanwhile nevertheless thus hence accordingly subsequently
    ].freeze

    TRANSITION_PHRASES = [
      'for example', 'for instance', 'in addition', 'on the other hand',
      'as a result', 'in contrast'
    ].freeze

    PASSIVE_INDICATORS = %w[was were been being is are am be].freeze

    def initialize
      @target_reading_level = [8, 10]  # 8th-10th grade
      @target_flesch_ease = [60, 70]   # Fairly easy to read
      @max_avg_sentence_length = 20
      @max_paragraph_sentences = 4
    end

    # Comprehensive readability analysis
    #
    # @param content [String] Article content to analyze
    # @return [Hash] Readability scores, metrics, and recommendations
    def analyze(content)
      clean_text = clean_content(content)

      return { error: 'No readable content provided' } if clean_text.empty?

      # Calculate all metrics
      metrics = calculate_metrics(clean_text)

      # Analyze structure
      structure = analyze_structure(content, clean_text)

      # Analyze complexity
      complexity = analyze_complexity(clean_text)

      # Generate score and grade
      overall_score = calculate_overall_score(metrics, structure, complexity)
      grade = get_grade(overall_score)

      # Generate recommendations
      recommendations = generate_recommendations(metrics, structure, complexity)

      {
        overall_score: overall_score,
        grade: grade,
        reading_level: metrics[:flesch_kincaid_grade],
        readability_metrics: metrics,
        structure_analysis: structure,
        complexity_analysis: complexity,
        recommendations: recommendations,
        status: get_status(metrics, structure)
      }
    end

    private

    # Clean content for readability analysis
    def clean_content(content)
      text = content.dup

      # Remove markdown headers
      text.gsub!(/^#+\s+/m, '')

      # Remove links but keep text
      text.gsub!(/\[([^\]]+)\]\([^)]+\)/, '\1')

      # Remove code blocks
      text.gsub!(/```[^`]*```/m, '')

      # Remove extra whitespace
      text.gsub!(/\n\s*\n/, "\n\n")
      text.strip
    end

    # Calculate readability metrics
    def calculate_metrics(text)
      words = text.split
      sentences = Helpers::TextUtils.extract_sentences(text)
      syllables = count_syllables(text)

      word_count = words.length
      sentence_count = [sentences.length, 1].max
      syllable_count = syllables

      avg_words_per_sentence = word_count.to_f / sentence_count
      avg_syllables_per_word = syllable_count.to_f / [word_count, 1].max

      # Flesch Reading Ease: 206.835 - 1.015(words/sentences) - 84.6(syllables/words)
      flesch_reading_ease = 206.835 - (1.015 * avg_words_per_sentence) - (84.6 * avg_syllables_per_word)
      flesch_reading_ease = [[flesch_reading_ease, 0].max, 100].min

      # Flesch-Kincaid Grade Level: 0.39(words/sentences) + 11.8(syllables/words) - 15.59
      flesch_kincaid_grade = (0.39 * avg_words_per_sentence) + (11.8 * avg_syllables_per_word) - 15.59
      flesch_kincaid_grade = [flesch_kincaid_grade, 0].max

      # Gunning Fog Index
      complex_words = words.count { |w| count_syllables_word(w) >= 3 }
      gunning_fog = 0.4 * (avg_words_per_sentence + (100 * complex_words.to_f / [word_count, 1].max))

      # Coleman-Liau Index: 0.0588L - 0.296S - 15.8
      # L = average number of letters per 100 words, S = average number of sentences per 100 words
      letter_count = text.gsub(/[^a-zA-Z]/, '').length
      l = (letter_count.to_f / [word_count, 1].max) * 100
      s = (sentence_count.to_f / [word_count, 1].max) * 100
      coleman_liau = (0.0588 * l) - (0.296 * s) - 15.8

      # Count polysyllabic words
      polysyllable_count = words.count { |w| count_syllables_word(w) >= 3 }

      {
        flesch_reading_ease: flesch_reading_ease.round(1),
        flesch_kincaid_grade: flesch_kincaid_grade.round(1),
        gunning_fog: gunning_fog.round(1),
        smog_index: calculate_smog(sentence_count, polysyllable_count).round(1),
        coleman_liau_index: coleman_liau.round(1),
        automated_readability_index: calculate_ari(word_count, sentence_count, letter_count).round(1),
        syllable_count: syllable_count,
        lexicon_count: word_count,
        sentence_count: sentence_count,
        char_count: text.length,
        letter_count: letter_count,
        polysyllable_count: polysyllable_count
      }
    rescue StandardError => e
      {
        error: "Could not calculate metrics: #{e.message}",
        flesch_reading_ease: 0,
        flesch_kincaid_grade: 0
      }
    end

    # Count syllables in text
    def count_syllables(text)
      words = text.split
      words.sum { |word| count_syllables_word(word) }
    end

    # Count syllables in a single word
    def count_syllables_word(word)
      word = word.downcase.gsub(/[^a-z]/, '')
      return 0 if word.empty?

      # Simple syllable counting based on vowel groups
      vowels = word.scan(/[aeiouy]+/)
      count = vowels.length

      # Adjust for silent e at end
      count -= 1 if word.end_with?('e') && count > 1

      # At least one syllable
      [count, 1].max
    end

    # Calculate SMOG index
    def calculate_smog(sentence_count, polysyllable_count)
      return 0 if sentence_count.zero?

      1.0430 * Math.sqrt(polysyllable_count * (30.0 / sentence_count)) + 3.1291
    end

    # Calculate Automated Readability Index
    def calculate_ari(word_count, sentence_count, char_count)
      return 0 if word_count.zero? || sentence_count.zero?

      (4.71 * (char_count.to_f / word_count)) + (0.5 * (word_count.to_f / sentence_count)) - 21.43
    end

    # Analyze content structure
    def analyze_structure(original, clean_text)
      sentences = Helpers::TextUtils.extract_sentences(clean_text)
      sentence_lengths = sentences.map { |s| s.split.length }

      avg_sentence_length = sentence_lengths.empty? ? 0 : sentence_lengths.sum.to_f / sentence_lengths.length

      # Paragraph analysis
      paragraphs = original.split(/\n\n+/).reject { |p| p.strip.empty? || p.strip.start_with?('#') }
      paragraph_sentence_counts = paragraphs.map do |para|
        para.split(/[.!?]+/).map(&:strip).reject(&:empty?).length
      end.reject(&:zero?)

      avg_sentences_per_paragraph = if paragraph_sentence_counts.empty?
                                      0
                                    else
                                      paragraph_sentence_counts.sum.to_f / paragraph_sentence_counts.length
                                    end

      # Word analysis
      words = clean_text.split
      word_lengths = words.map(&:length)
      avg_word_length = word_lengths.empty? ? 0 : word_lengths.sum.to_f / word_lengths.length

      {
        total_sentences: sentences.length,
        avg_sentence_length: avg_sentence_length.round(1),
        shortest_sentence: sentence_lengths.min || 0,
        longest_sentence: sentence_lengths.max || 0,
        sentence_length_variance: calculate_variance(sentence_lengths).round(1),
        total_paragraphs: paragraphs.length,
        avg_sentences_per_paragraph: avg_sentences_per_paragraph.round(1),
        total_words: words.length,
        avg_word_length: avg_word_length.round(1),
        long_sentences: sentence_lengths.count { |l| l > 25 },
        very_long_sentences: sentence_lengths.count { |l| l > 35 }
      }
    end

    # Analyze text complexity indicators
    def analyze_complexity(text)
      text_lower = text.downcase

      # Transition words count
      transition_count = TRANSITION_WORDS.sum { |word| text_lower.scan(/\b#{word}\b/).length }
      transition_count += TRANSITION_PHRASES.sum { |phrase| text_lower.scan(phrase).length }

      # Passive voice detection
      sentences = text.split(/[.!?]+/)
      passive_count = sentences.count do |sentence|
        sentence_lower = sentence.downcase
        has_passive_verb = PASSIVE_INDICATORS.any? { |word| sentence_lower.include?(" #{word} ") }
        has_past_participle = sentence_lower.match?(/\b\w+(ed|en)\b/)
        has_passive_verb && has_past_participle
      end

      total_sentences = [sentences.reject(&:empty?).length, 1].max
      passive_ratio = (passive_count.to_f / total_sentences) * 100

      # Complex words (3+ syllables)
      words = text.split
      complex_word_count = words.count { |word| count_syllables_word(word) >= 3 }
      complex_word_ratio = words.empty? ? 0 : (complex_word_count.to_f / words.length) * 100

      {
        transition_word_count: transition_count,
        transition_words_per_100: words.empty? ? 0 : (transition_count.to_f / words.length * 100).round(1),
        passive_sentence_count: passive_count,
        passive_sentence_ratio: passive_ratio.round(1),
        complex_word_count: complex_word_count,
        complex_word_ratio: complex_word_ratio.round(1)
      }
    end

    # Calculate overall readability score (0-100)
    def calculate_overall_score(metrics, structure, complexity)
      score = 100

      # Flesch Reading Ease scoring (30 points)
      flesch = metrics[:flesch_reading_ease] || 0
      if flesch < 30
        score -= 30
      elsif flesch < 50
        score -= 20
      elsif flesch < 60
        score -= 10
      elsif flesch > 80
        score -= 5 # Too easy might not sound professional
      end

      # Grade level scoring (25 points)
      grade = metrics[:flesch_kincaid_grade] || 0
      target_min, target_max = @target_reading_level
      if grade < target_min - 2
        score -= 10 # Too simple
      elsif grade > target_max + 4
        score -= 25
      elsif grade > target_max + 2
        score -= 15
      elsif grade > target_max
        score -= 5
      end

      # Sentence length scoring (20 points)
      avg_sentence = structure[:avg_sentence_length] || 0
      if avg_sentence > 30
        score -= 20
      elsif avg_sentence > 25
        score -= 10
      elsif avg_sentence > 20
        score -= 5
      end

      # Very long sentences penalty
      very_long = structure[:very_long_sentences] || 0
      score -= [15, very_long * 3].min if very_long.positive?

      # Paragraph structure (10 points)
      avg_para_sentences = structure[:avg_sentences_per_paragraph] || 0
      if avg_para_sentences > 6
        score -= 10
      elsif avg_para_sentences > 4
        score -= 5
      end

      # Passive voice penalty (10 points)
      passive_ratio = complexity[:passive_sentence_ratio] || 0
      if passive_ratio > 30
        score -= 10
      elsif passive_ratio > 20
        score -= 5
      end

      # Transition words bonus (5 points)
      transition_per_100 = complexity[:transition_words_per_100] || 0
      if transition_per_100 < 0.5
        score -= 5
      elsif transition_per_100 > 2
        score += 5
      end

      [[score, 0].max, 100].min
    end

    # Convert score to letter grade
    def get_grade(score)
      Helpers::Scoring.letter_grade(score)
    end

    # Get quick status assessment
    def get_status(metrics, structure)
      grade_level = metrics[:flesch_kincaid_grade] || 0
      flesch_ease = metrics[:flesch_reading_ease] || 0
      avg_sentence = structure[:avg_sentence_length] || 0

      target_min, target_max = @target_reading_level

      grade_status = if grade_level.between?(target_min, target_max)
                       'optimal'
                     elsif grade_level < target_min
                       'too_simple'
                     else
                       'too_complex'
                     end

      ease_status = if flesch_ease.between?(60, 80)
                      'good'
                    elsif flesch_ease < 60
                      'difficult'
                    else
                      'too_easy'
                    end

      sentence_status = avg_sentence <= @max_avg_sentence_length ? 'good' : 'too_long'

      overall_assessment = if [grade_status, ease_status, sentence_status].all? { |s| %w[good optimal].include?(s) }
                             'excellent'
                           elsif %w[too_complex difficult too_long].any? { |s| [grade_status, ease_status, sentence_status].include?(s) }
                             'needs_improvement'
                           else
                             'acceptable'
                           end

      {
        grade_level_status: grade_status,
        ease_status: ease_status,
        sentence_length_status: sentence_status,
        overall_assessment: overall_assessment
      }
    end

    # Generate actionable recommendations
    def generate_recommendations(metrics, structure, complexity)
      recommendations = []

      # Reading level
      grade = metrics[:flesch_kincaid_grade] || 0
      target_min, target_max = @target_reading_level

      if grade > target_max + 2
        recommendations << "Reading level is too high (Grade #{grade}). Target is #{target_min}-#{target_max}. " \
                           'Simplify sentences and use more common words.'
      elsif grade > target_max
        recommendations << "Reading level is slightly high (Grade #{grade}). Target is #{target_min}-#{target_max}. " \
                           'Consider simplifying some complex sentences.'
      elsif grade < target_min - 2
        recommendations << "Reading level is very simple (Grade #{grade}). Consider adding more depth and variation."
      end

      # Flesch Reading Ease
      flesch = metrics[:flesch_reading_ease] || 0
      if flesch < 50
        recommendations << "Content is difficult to read (Flesch score: #{flesch}). " \
                           'Break up complex sentences and use simpler words.'
      elsif flesch < 60
        recommendations << "Content is fairly difficult (Flesch score: #{flesch}). Aim for 60-70 for better readability."
      end

      # Sentence length
      avg_sentence = structure[:avg_sentence_length] || 0
      long_sentences = structure[:long_sentences] || 0
      very_long = structure[:very_long_sentences] || 0

      if avg_sentence > 25
        recommendations << "Average sentence length is too long (#{avg_sentence} words). " \
                           "Target is under #{@max_avg_sentence_length} words. Break up long sentences."
      elsif avg_sentence > 20
        recommendations << "Average sentence length is high (#{avg_sentence} words). " \
                           'Consider shortening some sentences for better flow.'
      end

      if very_long.positive?
        recommendations << "#{very_long} sentences are very long (35+ words). These should be split into multiple sentences."
      elsif long_sentences > (structure[:total_sentences] || 1) * 0.2
        recommendations << "#{long_sentences} sentences are long (25+ words). Breaking these up would improve readability."
      end

      # Paragraph structure
      avg_para = structure[:avg_sentences_per_paragraph] || 0
      if avg_para > 6
        recommendations << "Paragraphs are too long (avg #{avg_para} sentences). " \
                           "Keep paragraphs to #{@max_paragraph_sentences} sentences or less."
      elsif avg_para > 4
        recommendations << "Paragraphs are fairly long (avg #{avg_para} sentences). Consider breaking into smaller chunks."
      end

      # Passive voice
      passive_ratio = complexity[:passive_sentence_ratio] || 0
      if passive_ratio > 30
        recommendations << "Too much passive voice (#{passive_ratio.round}% of sentences). " \
                           'Convert to active voice where possible (target: under 20%).'
      elsif passive_ratio > 20
        recommendations << "Passive voice is slightly high (#{passive_ratio.round}%). " \
                           'Try to use more active voice for direct, engaging writing.'
      end

      # Transition words
      transition_per_100 = complexity[:transition_words_per_100] || 0
      if transition_per_100 < 0.5
        recommendations << "Few transition words detected. Add words like 'however', 'therefore', " \
                           "'additionally' to improve flow between ideas."
      end

      # Complex words
      complex_ratio = complexity[:complex_word_ratio] || 0
      if complex_ratio > 15
        recommendations << "High percentage of complex words (#{complex_ratio.round(1)}%). " \
                           'Consider simpler alternatives where appropriate.'
      end

      recommendations << 'Readability is excellent! Content is clear and accessible.' if recommendations.empty?

      recommendations
    end

    # Calculate variance
    def calculate_variance(values)
      return 0 if values.length < 2

      mean = values.sum.to_f / values.length
      values.sum { |x| (x - mean)**2 } / values.length
    end
  end
end
