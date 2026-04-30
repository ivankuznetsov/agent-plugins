# frozen_string_literal: true

require 'faraday'
require 'base64'
require 'json'

module AgentSeo
  # DataForSEO API Integration
  # Fetches SERP data, competitor rankings, keyword research, and more.
  class DataForSeo
    attr_reader :base_url

    # Initialize DataForSEO client
    #
    # @param login [String] API login (defaults to env var)
    # @param password [String] API password (defaults to env var)
    def initialize(login: nil, password: nil)
      @login = login || ENV.fetch('DATAFORSEO_LOGIN', nil)
      @password = password || ENV.fetch('DATAFORSEO_PASSWORD', nil)
      @base_url = ENV.fetch('DATAFORSEO_BASE_URL', 'https://api.dataforseo.com')

      raise ConfigurationError, 'DATAFORSEO_LOGIN and DATAFORSEO_PASSWORD must be set' unless @login && @password

      encoded_cred = Base64.strict_encode64("#{@login}:#{@password}")

      @connection = Faraday.new(url: @base_url) do |f|
        f.request :json
        f.response :json
        f.headers['Authorization'] = "Basic #{encoded_cred}"
        f.headers['Content-Type'] = 'application/json'
        f.adapter Faraday.default_adapter
      end
    end

    # Get ranking positions for specific keywords
    #
    # @param domain [String] Your domain (e.g., "example.com")
    # @param keywords [Array<String>] List of keywords to check
    # @param location_code [Integer] DataForSEO location code (2840 = USA)
    # @param language_code [String] Language code
    # @return [Array<Hash>] Ranking data for each keyword
    def get_rankings(domain:, keywords:, location_code: 2840, language_code: 'en')
      tasks = keywords.map do |keyword|
        {
          keyword: keyword,
          location_code: location_code,
          language_code: language_code,
          device: 'desktop',
          os: 'windows'
        }
      end

      response = post('/v3/serp/google/organic/live/advanced', tasks)

      return [] unless response['status_code'] == 20_000

      response['tasks'].filter_map do |task|
        next unless task['status_code'] == 20_000

        keyword = task.dig('data', 'keyword')
        items = task.dig('result', 0, 'items') || []

        # Find domain position
        position = nil
        url = nil
        items.each_with_index do |item, index|
          if item['domain']&.include?(domain)
            position = index + 1
            url = item['url']
            break
          end
        end

        keyword_data = task.dig('result', 0, 'keyword_data', 'keyword_info') || {}

        {
          keyword: keyword,
          domain: domain,
          position: position,
          url: url,
          ranking: !position.nil?,
          search_volume: keyword_data['search_volume'],
          cpc: keyword_data['cpc']
        }
      end
    end

    # Get complete SERP data for a keyword
    #
    # @param keyword [String] Search keyword
    # @param location_code [Integer] DataForSEO location code
    # @param limit [Integer] Number of results to return
    # @return [Hash] SERP data including all ranking pages
    def get_serp_data(keyword, location_code: 2840, limit: 100)
      data = [{
        keyword: keyword,
        location_code: location_code,
        language_code: 'en',
        device: 'desktop',
        os: 'windows',
        depth: limit
      }]

      response = post('/v3/serp/google/organic/live/advanced', data)

      return { error: 'API request failed' } unless response['status_code'] == 20_000

      task = response['tasks'][0]
      return { error: 'Task failed' } unless task['status_code'] == 20_000

      result = task['result'][0]
      items = result['items'] || []

      # Extract organic results
      organic_results = items.select { |item| item['type'] == 'organic' }.map do |item|
        {
          position: item['rank_absolute'],
          url: item['url'],
          domain: item['domain'],
          title: item['title'],
          description: item['description'],
          breadcrumb: item['breadcrumb']
        }
      end

      # Extract SERP features
      features = items.reject { |item| item['type'] == 'organic' }.map { |item| item['type'] }.uniq

      keyword_data = result.dig('keyword_data', 'keyword_info') || {}

      {
        keyword: keyword,
        search_volume: keyword_data['search_volume'],
        cpc: keyword_data['cpc'],
        competition: keyword_data['competition'],
        organic_results: organic_results,
        features: features,
        total_results: result['items_count'] || 0
      }
    end

    # Analyze competitor rankings vs yours
    #
    # @param competitor_domain [String] Competitor's domain
    # @param keywords [Array<String>] Keywords to compare
    # @param your_domain [String] Your domain (optional)
    # @return [Hash] Comparative ranking analysis
    def analyze_competitor(competitor_domain:, keywords:, your_domain: nil)
      tasks = keywords.map do |keyword|
        {
          keyword: keyword,
          location_code: 2840,
          language_code: 'en',
          device: 'desktop'
        }
      end

      response = post('/v3/serp/google/organic/live/advanced', tasks)

      comparison = response['tasks'].map.with_index do |task, i|
        next unless task['status_code'] == 20_000

        keyword = keywords[i]
        items = task.dig('result', 0, 'items') || []

        competitor_pos = nil
        your_pos = nil

        items.each_with_index do |item, j|
          domain = item['domain'] || ''
          competitor_pos = j + 1 if domain.include?(competitor_domain)
          your_pos = j + 1 if your_domain && domain.include?(your_domain)
        end

        gap = if competitor_pos && your_pos
                your_pos - competitor_pos
              elsif competitor_pos && !your_pos
                'Not ranking'
              end

        opportunity = if competitor_pos && !your_pos
                        'high'
                      elsif gap.is_a?(Numeric) && gap > 10
                        'medium'
                      else
                        'low'
                      end

        {
          keyword: keyword,
          competitor_position: competitor_pos,
          your_position: your_pos,
          gap: gap,
          opportunity: opportunity
        }
      end.compact

      {
        competitor: competitor_domain,
        your_domain: your_domain,
        comparison: comparison
      }
    end

    # Get related keyword ideas
    #
    # @param seed_keyword [String] Starting keyword
    # @param location_code [Integer] Location code
    # @param limit [Integer] Number of ideas to return
    # @return [Array<Hash>] Related keywords with search volume, difficulty
    def get_keyword_ideas(seed_keyword, location_code: 2840, limit: 100)
      data = [{
        keyword: seed_keyword,
        location_code: location_code,
        language_code: 'en',
        include_serp_info: true,
        limit: limit
      }]

      response = post('/v3/dataforseo_labs/google/related_keywords/live', data)

      return [] unless response['status_code'] == 20_000

      task = response['tasks'][0]
      return [] unless task['status_code'] == 20_000

      items = task.dig('result', 0, 'items') || []

      keywords = items.map do |item|
        keyword_info = item.dig('keyword_data', 'keyword_info') || {}
        {
          keyword: item.dig('keyword_data', 'keyword'),
          search_volume: keyword_info['search_volume'],
          cpc: keyword_info['cpc'],
          competition: keyword_info['competition'],
          avg_position: item.dig('serp_info', 'se_results_count')
        }
      end

      keywords.sort_by { |k| -(k[:search_volume] || 0) }
    end

    # Get question-based queries related to keyword
    #
    # @param keyword [String] Seed keyword
    # @param location_code [Integer] Location code
    # @param limit [Integer] Number of questions to return
    # @return [Array<Hash>] Question queries
    def get_questions(keyword, location_code: 2840, limit: 50)
      data = [{
        keyword: keyword,
        location_code: location_code,
        language_code: 'en',
        limit: limit
      }]

      response = post('/v3/dataforseo_labs/google/related_keywords/live', data)

      return [] unless response['status_code'] == 20_000

      task = response['tasks'][0]
      return [] unless task['status_code'] == 20_000

      items = task.dig('result', 0, 'items') || []

      question_starters = %w[how what why when where who can should is are does]

      questions = items.filter_map do |item|
        kw = item.dig('keyword_data', 'keyword') || ''
        kw_lower = kw.downcase

        next unless question_starters.any? { |q| kw_lower.start_with?(q) }

        keyword_info = item.dig('keyword_data', 'keyword_info') || {}
        {
          question: kw,
          search_volume: keyword_info['search_volume'],
          cpc: keyword_info['cpc']
        }
      end

      questions.sort_by { |q| -(q[:search_volume] || 0) }
    end

    # Get domain overview metrics
    #
    # @param domain [String] Domain to analyze
    # @return [Hash] Domain metrics
    def get_domain_metrics(domain)
      data = [{
        target: domain,
        location_code: 2840,
        language_code: 'en'
      }]

      response = post('/v3/dataforseo_labs/google/domain_metrics/live', data)

      return {} unless response['status_code'] == 20_000

      task = response['tasks'][0]
      return {} unless task['status_code'] == 20_000

      metrics = task.dig('result', 0, 'items', 0, 'metrics') || {}

      {
        domain: domain,
        organic_keywords: metrics.dig('organic', 'count'),
        organic_traffic: metrics.dig('organic', 'etv'),
        domain_rank: metrics.dig('organic', 'rank'),
        backlinks: metrics['backlinks']
      }
    end

    # Get ranking history for a keyword
    #
    # @param domain [String] Your domain
    # @param keyword [String] Keyword to track
    # @param months_back [Integer] Months of history
    # @return [Array<Hash>] Historical rankings
    def check_ranking_history(domain:, keyword:, months_back: 3)
      data = [{
        target: domain,
        keyword: keyword,
        location_code: 2840,
        language_code: 'en'
      }]

      begin
        response = post('/v3/serp/google/organic/ranking_history/live', data)

        if response['status_code'] == 20_000
          task = response['tasks'][0]
          return task.dig('result', 0, 'items') || [] if task['status_code'] == 20_000
        end
      rescue StandardError => e
        AgentSeo.logger.warn("#{self.class}##{__method__} failed: #{e.message}")
        AgentSeo.logger.debug { e.backtrace.first(5).join("\n") } if AgentSeo.logger.debug?
      end

      []
    end

    private

    # Make POST request to DataForSEO API
    #
    # @param endpoint [String] API endpoint
    # @param data [Array] Request data
    # @return [Hash] Response data
    def post(endpoint, data)
      response = @connection.post(endpoint, data)
      response.body
    end
  end
end
