# frozen_string_literal: true

module AgentSeo
  # Search Intent Analyzer (Pattern-Based Fallback)
  #
  # Determines the search intent of a query by analyzing SERP features and content patterns.
  # Classifies queries as: Informational, Navigational, Transactional, or Commercial Investigation.
  #
  # NOTE: For more accurate intent analysis, use the LLM-based agent at:
  # .claude/agents/search-intent-analyzer.md
  #
  # This pattern-based analyzer serves as a fallback when LLM is not available.
  class SearchIntentAnalyzer
    # Search intent types
    INTENTS = %i[informational navigational transactional commercial].freeze

    # Intent signal keywords
    INFORMATIONAL_SIGNALS = %w[
      what why how when where who guide tutorial learn tips
    ].freeze

    INFORMATIONAL_PHRASES = ['best practices', 'explained', 'definition', 'meaning'].freeze

    NAVIGATIONAL_SIGNALS = %w[
      login website official account dashboard portal app
    ].freeze

    NAVIGATIONAL_PHRASES = ['sign in', 'home page'].freeze

    TRANSACTIONAL_SIGNALS = %w[
      buy purchase order download get pricing cost subscribe install coupon deal discount cheap affordable
    ].freeze

    TRANSACTIONAL_PHRASES = ['free trial', 'sign up'].freeze

    COMMERCIAL_SIGNALS = %w[
      best top review vs versus compare comparison alternative alternatives like similar option choice
    ].freeze

    COMMERCIAL_PHRASES = ['better than', 'instead of'].freeze

    # Analyze search intent of a keyword
    #
    # @param keyword [String] The search query to analyze
    # @param serp_features [Array<String>] List of SERP features present (from DataForSEO)
    # @param top_results [Array<Hash>] Top ranking pages with titles/descriptions
    # @return [Hash] Intent classification and confidence scores
    def analyze(keyword, serp_features: nil, top_results: nil)
      keyword_lower = keyword.downcase

      # Calculate intent scores
      scores = INTENTS.to_h { |intent| [intent, 0.0] }

      # Score from keyword patterns
      keyword_scores = analyze_keyword_patterns(keyword_lower)
      keyword_scores.each { |intent, score| scores[intent] += score }

      # Score from SERP features
      if serp_features
        serp_scores = analyze_serp_features(serp_features)
        serp_scores.each { |intent, score| scores[intent] += score }
      end

      # Score from top results content
      if top_results
        content_scores = analyze_content_patterns(top_results)
        content_scores.each { |intent, score| scores[intent] += score }
      end

      # Normalize scores to percentages
      total = scores.values.sum
      confidence = if total.positive?
                     INTENTS.to_h { |intent| [intent.to_s, (scores[intent] / total * 100).round(1)] }
                   else
                     INTENTS.to_h { |intent| [intent.to_s, 25.0] }
                   end

      # Primary intent is highest scoring
      primary_intent = scores.max_by { |_, v| v }&.first

      # Secondary intent if within 15% of primary
      sorted_scores = scores.sort_by { |_, v| -v }
      secondary_intent = nil
      if sorted_scores.length > 1
        primary_pct = confidence[sorted_scores[0][0].to_s]
        secondary_pct = confidence[sorted_scores[1][0].to_s]
        secondary_intent = sorted_scores[1][0] if primary_pct - secondary_pct < 15
      end

      {
        keyword: keyword,
        primary_intent: primary_intent.to_s,
        secondary_intent: secondary_intent&.to_s,
        confidence: confidence,
        signals_detected: get_detected_signals(keyword_lower, serp_features),
        recommendations: get_recommendations(primary_intent, secondary_intent)
      }
    end

    private

    # Score keyword based on pattern matching
    def analyze_keyword_patterns(keyword)
      scores = INTENTS.to_h { |intent| [intent, 0.0] }

      # Check for signal words
      INFORMATIONAL_SIGNALS.each { |signal| scores[:informational] += 2 if keyword.include?(signal) }
      INFORMATIONAL_PHRASES.each { |phrase| scores[:informational] += 2 if keyword.include?(phrase) }

      NAVIGATIONAL_SIGNALS.each { |signal| scores[:navigational] += 3 if keyword.include?(signal) }
      NAVIGATIONAL_PHRASES.each { |phrase| scores[:navigational] += 3 if keyword.include?(phrase) }

      TRANSACTIONAL_SIGNALS.each { |signal| scores[:transactional] += 2 if keyword.include?(signal) }
      TRANSACTIONAL_PHRASES.each { |phrase| scores[:transactional] += 2 if keyword.include?(phrase) }

      COMMERCIAL_SIGNALS.each { |signal| scores[:commercial] += 2 if keyword.include?(signal) }
      COMMERCIAL_PHRASES.each { |phrase| scores[:commercial] += 2 if keyword.include?(phrase) }

      # Questions are typically informational
      if keyword.match?(/^(what|why|how|when|where|who|can|should|is|are|does)/)
        scores[:informational] += 3
      end

      # Brand + generic term = navigational
      scores[:navigational] += 1 if keyword.split.length == 2

      # Lists and comparisons = commercial
      scores[:commercial] += 3 if keyword.match?(/\d+\s+(best|top)/)

      scores
    end

    # Score based on SERP features present
    def analyze_serp_features(features)
      scores = INTENTS.to_h { |intent| [intent, 0.0] }

      features.each do |feature|
        feature_lower = feature.downcase

        # Map SERP features to intents
        scores[:informational] += 2 if feature_lower.include?('snippet') || feature_lower.include?('featured')
        scores[:informational] += 2 if feature_lower.include?('knowledge') || feature_lower.include?('people_also_ask')
        scores[:transactional] += 3 if feature_lower.include?('shopping') || feature_lower.include?('product')
        scores[:transactional] += 1 if feature_lower.include?('ad')
        scores[:transactional] += 2 if feature_lower.include?('local') || feature_lower.include?('map')
        scores[:informational] += 1 if feature_lower.include?('video')
        scores[:commercial] += 1 if feature_lower.include?('carousel')
      end

      scores
    end

    # Score based on top ranking content patterns
    def analyze_content_patterns(results)
      scores = INTENTS.to_h { |intent| [intent, 0.0] }

      results.first(10).each do |result|
        title = result['title']&.downcase || result[:title]&.downcase || ''
        description = result['description']&.downcase || result[:description]&.downcase || ''
        url = result['url']&.downcase || result[:url]&.downcase || ''

        combined = "#{title} #{description}"

        # Informational indicators
        if %w[guide how\ to what\ is tutorial tips].any? { |word| combined.include?(word) }
          scores[:informational] += 0.5
        end

        # Commercial indicators
        if %w[best top review vs compare].any? { |word| combined.include?(word) }
          scores[:commercial] += 0.5
        end

        # Transactional indicators
        if %w[buy price shop order get].any? { |word| combined.include?(word) }
          scores[:transactional] += 0.5
        end

        # Product/checkout pages in URLs
        if %w[/product/ /pricing /buy /shop /checkout].any? { |word| url.include?(word) }
          scores[:transactional] += 0.5
        end
      end

      scores
    end

    # Get list of signals detected for each intent
    def get_detected_signals(keyword, serp_features)
      signals = INTENTS.to_h { |intent| [intent.to_s, []] }

      # Keyword signals
      INFORMATIONAL_SIGNALS.each do |signal|
        signals['informational'] << "Keyword contains '#{signal}'" if keyword.include?(signal)
      end

      NAVIGATIONAL_SIGNALS.each do |signal|
        signals['navigational'] << "Keyword contains '#{signal}'" if keyword.include?(signal)
      end

      TRANSACTIONAL_SIGNALS.each do |signal|
        signals['transactional'] << "Keyword contains '#{signal}'" if keyword.include?(signal)
      end

      COMMERCIAL_SIGNALS.each do |signal|
        signals['commercial'] << "Keyword contains '#{signal}'" if keyword.include?(signal)
      end

      # SERP feature signals
      serp_features&.each do |feature|
        feature_lower = feature.downcase
        if feature_lower.include?('snippet') || feature_lower.include?('knowledge')
          signals['informational'] << "SERP has #{feature}"
        end
        if feature_lower.include?('shopping') || feature_lower.include?('ad')
          signals['transactional'] << "SERP has #{feature}"
        end
      end

      signals.reject { |_, v| v.empty? }
    end

    # Get content recommendations based on intent
    def get_recommendations(primary, secondary)
      recommendations = []

      case primary
      when :informational
        recommendations.concat([
                                 'Create comprehensive, educational content',
                                 'Include step-by-step instructions or explanations',
                                 'Answer common questions (People Also Ask)',
                                 'Use FAQ sections and definition boxes',
                                 'Target featured snippet optimization',
                                 'Include videos, images, and visual aids'
                               ])
      when :navigational
        recommendations.concat([
                                 'Optimize for brand-related searches',
                                 'Ensure homepage/key pages rank well',
                                 'Include site navigation and clear CTAs',
                                 'Strengthen brand presence and awareness',
                                 'May not need traditional content marketing'
                               ])
      when :transactional
        recommendations.concat([
                                 'Focus on product/service pages',
                                 'Include clear pricing and purchase options',
                                 'Add trust signals (reviews, testimonials)',
                                 'Optimize for conversion, not just traffic',
                                 'Include strong, action-oriented CTAs',
                                 'Consider local SEO if applicable'
                               ])
      when :commercial
        recommendations.concat([
                                 'Create comparison and review content',
                                 'Include pros/cons and alternatives',
                                 'Add detailed feature breakdowns',
                                 'Include data tables and comparisons',
                                 "Show 'best for' categories",
                                 'Help users make informed decisions'
                               ])
      end

      if secondary
        recommendations << "\nNote: Secondary intent is #{secondary} - consider blending content approaches"
      end

      recommendations
    end
  end
end
