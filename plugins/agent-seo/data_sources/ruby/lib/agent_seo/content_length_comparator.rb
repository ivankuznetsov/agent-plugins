# frozen_string_literal: true

require 'faraday'
require 'nokogiri'

module AgentSeo
  # Content Length Comparator
  # Fetches top SERP results for a keyword and analyzes their content length
  # to determine optimal word count for ranking competitively.
  class ContentLengthComparator
    USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'

    def initialize
      @connection = Faraday.new do |f|
        f.headers['User-Agent'] = USER_AGENT
        f.options.timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    # Analyze content length compared to SERP competitors
    #
    # @param keyword [String] Search keyword to analyze
    # @param your_word_count [Integer] Your content's word count
    # @param serp_results [Array<Hash>] SERP results from DataForSEO
    # @param fetch_content [Boolean] Whether to fetch and analyze competitor content
    # @return [Hash] Length comparison, recommendations, and statistics
    def analyze(keyword, your_word_count: nil, serp_results: nil, fetch_content: true)
      unless serp_results&.any?
        return {
          error: 'No SERP results provided',
          recommendation: 'Use DataForSEO to get SERP data first'
        }
      end

      # Analyze competitor content lengths
      competitor_lengths = []

      if fetch_content
        serp_results.first(10).each_with_index do |result, i|
          url = result['url'] || result[:url]
          next unless url

          word_count = fetch_word_count(url)
          next unless word_count

          competitor_lengths << {
            position: i + 1,
            url: url,
            domain: result['domain'] || result[:domain] || '',
            title: (result['title'] || result[:title] || '')[0, 100],
            word_count: word_count
          }
        end
      end

      if competitor_lengths.empty?
        return {
          error: 'Could not fetch competitor content',
          recommendation: 'Manually check top ranking pages for word count'
        }
      end

      # Calculate statistics
      counts = competitor_lengths.map { |c| c[:word_count] }
      stats = calculate_statistics(counts)

      # Determine recommended length
      recommendation = get_recommendation(stats, your_word_count)

      # Position your content
      your_position = if your_word_count
                        get_position_in_range(your_word_count, competitor_lengths)
                      end

      {
        keyword: keyword,
        competitors_analyzed: competitor_lengths.length,
        your_word_count: your_word_count,
        statistics: stats,
        competitor_lengths: competitor_lengths,
        your_position: your_position,
        recommendation: recommendation,
        competitive_analysis: analyze_competition(your_word_count, competitor_lengths, stats)
      }
    end

    private

    # Fetch and count words from a URL
    def fetch_word_count(url)
      response = @connection.get(url)
      return nil unless response.success?

      doc = Nokogiri::HTML(response.body)

      # Remove script, style, nav, footer, header elements
      %w[script style nav footer header aside].each do |tag|
        doc.css(tag).remove
      end

      # Try to find main content area
      main_content = nil
      %w[article main [role="main"] .content #content .post .entry-content].each do |selector|
        main_content = doc.at_css(selector)
        break if main_content
      end

      # If no main content found, use body
      main_content ||= doc.at_css('body')

      return nil unless main_content

      text = main_content.text.gsub(/\s+/, ' ').strip
      words = text.scan(/\b[a-zA-Z]{2,}\b/)
      words.length
    rescue StandardError => e
      AgentSeo.logger.warn("#{self.class}##{__method__} failed for #{url}: #{e.message}")
      AgentSeo.logger.debug { e.backtrace.first(5).join("\n") } if AgentSeo.logger.debug?
      nil
    end

    # Calculate statistical measures
    def calculate_statistics(counts)
      return {} if counts.empty?

      sorted = counts.sort
      n = counts.length

      mean = counts.sum.to_f / n
      median = if n.odd?
                 sorted[n / 2]
               else
                 (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
               end

      mode = counts.tally.max_by { |_, v| v }&.first || counts.first

      variance = counts.sum { |x| (x - mean)**2 } / n.to_f
      std_dev = Math.sqrt(variance)

      # Percentiles
      percentile_25 = sorted[(n * 0.25).floor]
      percentile_75 = sorted[(n * 0.75).floor]

      {
        min: counts.min,
        max: counts.max,
        mean: mean.round,
        median: median.round,
        mode: mode.round,
        std_dev: n > 1 ? std_dev.round : 0,
        percentile_25: percentile_25,
        percentile_75: percentile_75
      }
    end

    # Generate content length recommendation
    def get_recommendation(stats, your_count)
      return { error: 'Insufficient data' } if stats.empty?

      target_median = stats[:median]
      target_75th = stats[:percentile_75]

      # Recommended range
      recommended_min = target_median
      recommended_optimal = [target_75th, (target_median * 1.2).to_i].max
      recommended_max = (recommended_optimal * 1.2).to_i

      status = nil
      message = nil

      if your_count
        if your_count < recommended_min * 0.8
          status = 'too_short'
          message = "Your content is significantly shorter than competitors. Add #{recommended_optimal - your_count} more words."
        elsif your_count < recommended_min
          status = 'short'
          message = "Your content is shorter than most competitors. Consider adding #{recommended_optimal - your_count} more words."
        elsif your_count < recommended_optimal
          status = 'good'
          message = "Your content length is competitive. Add #{recommended_optimal - your_count} more words to match top performers."
        elsif your_count <= recommended_max
          status = 'optimal'
          message = 'Your content length is optimal - matches or exceeds top competitors.'
        else
          status = 'long'
          message = 'Your content is longer than competitors. Ensure all content adds value.'
        end
      end

      {
        recommended_min: recommended_min,
        recommended_optimal: recommended_optimal,
        recommended_max: recommended_max,
        your_status: status,
        message: message,
        reasoning: "Based on median (#{target_median}) and 75th percentile (#{target_75th}) of top 10 results"
      }
    end

    # Determine where your content falls in the competitor range
    def get_position_in_range(your_count, competitors)
      counts = competitors.map { |c| c[:word_count] }.sort

      if your_count < counts.first
        "Below all competitors (shortest is #{counts.first})"
      elsif your_count > counts.last
        "Above all competitors (longest is #{counts.last})"
      else
        # Find position
        counts.each_with_index do |count, i|
          return "Between position #{i} and #{i + 1} competitors" if your_count <= count
        end
        'Within competitive range'
      end
    end

    # Provide competitive analysis
    def analyze_competition(your_count, competitors, stats)
      analysis = {
        total_competitors: competitors.length,
        length_distribution: categorize_lengths(competitors)
      }

      if your_count && stats.any?
        shorter_than_you = competitors.count { |c| c[:word_count] < your_count }
        longer_than_you = competitors.count { |c| c[:word_count] > your_count }

        analysis[:comparison] = {
          shorter_than_you: shorter_than_you,
          longer_than_you: longer_than_you,
          percentile: competitors.any? ? (shorter_than_you.to_f / competitors.length * 100).round : 0
        }

        # Gap analysis
        if your_count < stats[:median]
          gap = stats[:median] - your_count
          analysis[:gap_to_median] = {
            words: gap,
            percentage: (gap.to_f / your_count * 100).round
          }
        end

        if your_count < stats[:percentile_75]
          gap = stats[:percentile_75] - your_count
          analysis[:gap_to_75th_percentile] = {
            words: gap,
            percentage: your_count.positive? ? (gap.to_f / your_count * 100).round : 0
          }
        end
      end

      analysis
    end

    # Categorize competitor content by length ranges
    def categorize_lengths(competitors)
      categories = {
        under_1000: 0,
        '1000_1500': 0,
        '1500_2000': 0,
        '2000_2500': 0,
        '2500_3000': 0,
        '3000_plus': 0
      }

      competitors.each do |comp|
        count = comp[:word_count]
        case count
        when 0...1000 then categories[:under_1000] += 1
        when 1000...1500 then categories[:'1000_1500'] += 1
        when 1500...2000 then categories[:'1500_2000'] += 1
        when 2000...2500 then categories[:'2000_2500'] += 1
        when 2500...3000 then categories[:'2500_3000'] += 1
        else categories[:'3000_plus'] += 1
        end
      end

      categories
    end
  end
end
