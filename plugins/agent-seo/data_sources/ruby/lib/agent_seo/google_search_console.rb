# frozen_string_literal: true

require 'google/apis/searchconsole_v1'
require 'googleauth'
require 'date'

module AgentSeo
  # Google Search Console Data Integration
  # Fetches search performance, keyword rankings, and SERP data.
  class GoogleSearchConsole
    SearchConsole = Google::Apis::SearchconsoleV1

    attr_reader :site_url, :service

    # Commercial intent signal terms for keyword scoring
    HIGH_INTENT_TERMS = %w[
      pricing price cost buy purchase vs versus alternative alternatives
      best top review reviews comparison compare plan plans trial
      discount coupon deal hosting service services platform software
      tool tools solution solutions provider providers
    ].freeze

    MEDIUM_HIGH_INTENT = %w[
      how\ to guide tutorial tips strategies examples ideas ways\ to
      for\ business for\ companies professional analytics monetization
      monetize grow increase improve optimize setup set\ up
    ].freeze

    MEDIUM_INTENT = %w[
      what\ is how\ does why benefits features podcast podcasting
      audio video rss marketing
    ].freeze

    LOW_INTENT_TERMS = %w[
      who\ is biography age net\ worth height wife husband
      dating married death died born pewdiepie youtube\ stars
      celebrity famous
    ].freeze

    # Initialize GSC client
    #
    # @param site_url [String] Site URL (e.g., "https://example.com")
    # @param credentials_path [String] Path to credentials JSON
    def initialize(site_url: nil, credentials_path: nil)
      @site_url = site_url || ENV.fetch('GSC_SITE_URL', nil)
      credentials_path ||= ENV.fetch('GSC_CREDENTIALS_PATH', nil)

      raise ConfigurationError, 'GSC_SITE_URL must be provided or set in environment' unless @site_url
      raise ConfigurationError, "Credentials file not found: #{credentials_path}" unless credentials_path && File.exist?(credentials_path)

      scope = ['https://www.googleapis.com/auth/webmasters.readonly']
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(credentials_path),
        scope: scope
      )

      @service = SearchConsole::SearchConsoleService.new
      @service.authorization = authorizer
    end

    # Get keyword rankings and performance
    #
    # @param days [Integer] Number of days to analyze
    # @param limit [Integer] Max number of keywords to return
    # @return [Array<Hash>] Keywords with position, clicks, impressions
    def get_keyword_positions(days: 30, limit: 1000)
      start_date = (Date.today - days).to_s
      end_date = Date.today.to_s

      request = SearchConsole::SearchAnalyticsQueryRequest.new(
        start_date: start_date,
        end_date: end_date,
        dimensions: ['query'],
        row_limit: limit
      )

      response = @service.query_searchanalytic(@site_url, request)

      return [] unless response.rows

      results = response.rows.map do |row|
        {
          keyword: row.keys[0],
          clicks: row.clicks,
          impressions: row.impressions,
          ctr: row.ctr,
          position: row.position.round(1)
        }
      end

      results.sort_by { |r| -r[:impressions] }
    end

    # Find "quick win" opportunities - keywords ranking 11-20
    #
    # @param days [Integer] Number of days to analyze
    # @param position_min [Integer] Minimum position (default 11)
    # @param position_max [Integer] Maximum position (default 20)
    # @param min_impressions [Integer] Minimum impressions threshold
    # @param prioritize_commercial [Boolean] Weight score by commercial intent
    # @return [Array<Hash>] Quick win opportunities
    def get_quick_wins(days: 30, position_min: 11, position_max: 20, min_impressions: 50, prioritize_commercial: true)
      all_keywords = get_keyword_positions(days: days)

      quick_wins = all_keywords.filter_map do |kw|
        next unless kw[:position].between?(position_min, position_max)
        next unless kw[:impressions] >= min_impressions

        keyword = kw[:keyword].downcase
        commercial_intent = calculate_commercial_intent(keyword)
        distance_from_10 = kw[:position] - 10
        base_score = kw[:impressions].to_f / (distance_from_10 + 1)

        opportunity_score = prioritize_commercial ? base_score * commercial_intent : base_score

        kw.merge(
          commercial_intent: commercial_intent,
          commercial_intent_category: get_intent_category(commercial_intent),
          opportunity_score: opportunity_score.round(2),
          priority: kw[:position] <= 15 ? 'high' : 'medium'
        )
      end

      quick_wins.sort_by { |q| -q[:opportunity_score] }
    end

    # Get search performance for a specific page
    #
    # @param url [String] Page URL or path
    # @param days [Integer] Number of days to analyze
    # @return [Hash] Page performance data
    def get_page_performance(url, days: 30)
      start_date = (Date.today - days).to_s
      end_date = Date.today.to_s

      operator = url.start_with?('http') ? 'equals' : 'contains'

      page_request = SearchConsole::SearchAnalyticsQueryRequest.new(
        start_date: start_date,
        end_date: end_date,
        dimensions: ['page'],
        dimension_filter_groups: [
          SearchConsole::ApiDimensionFilterGroup.new(
            filters: [
              SearchConsole::ApiDimensionFilter.new(
                dimension: 'page',
                operator: operator,
                expression: url
              )
            ]
          )
        ]
      )

      response = @service.query_searchanalytic(@site_url, page_request)

      return { url: url, error: 'No data found' } unless response.rows&.any?

      row = response.rows[0]
      page_data = {
        url: row.keys[0],
        clicks: row.clicks,
        impressions: row.impressions,
        ctr: (row.ctr * 100).round(2),
        avg_position: row.position.round(1)
      }

      # Get keywords for this page
      keywords_request = SearchConsole::SearchAnalyticsQueryRequest.new(
        start_date: start_date,
        end_date: end_date,
        dimensions: ['query'],
        dimension_filter_groups: [
          SearchConsole::ApiDimensionFilterGroup.new(
            filters: [
              SearchConsole::ApiDimensionFilter.new(
                dimension: 'page',
                operator: operator,
                expression: url
              )
            ]
          )
        ],
        row_limit: 50
      )

      keywords_response = @service.query_searchanalytic(@site_url, keywords_request)

      keywords = (keywords_response.rows || []).map do |kw_row|
        {
          keyword: kw_row.keys[0],
          clicks: kw_row.clicks,
          impressions: kw_row.impressions,
          position: kw_row.position.round(1)
        }
      end

      keywords.sort_by! { |k| -k[:clicks] }
      page_data[:top_keywords] = keywords.first(10)

      page_data
    end

    # Find pages with high impressions but low CTR
    #
    # @param days [Integer] Number of days to analyze
    # @param ctr_threshold [Float] CTR below this is considered low
    # @param min_impressions [Integer] Minimum impressions to consider
    # @param path_filter [String] Filter by path
    # @return [Array<Hash>] Pages with low CTR
    def get_low_ctr_pages(days: 30, ctr_threshold: 0.03, min_impressions: 100, path_filter: '/blog/')
      start_date = (Date.today - days).to_s
      end_date = Date.today.to_s

      request = SearchConsole::SearchAnalyticsQueryRequest.new(
        start_date: start_date,
        end_date: end_date,
        dimensions: ['page'],
        row_limit: 1000
      )

      if path_filter
        request.dimension_filter_groups = [
          SearchConsole::ApiDimensionFilterGroup.new(
            filters: [
              SearchConsole::ApiDimensionFilter.new(
                dimension: 'page',
                operator: 'contains',
                expression: path_filter
              )
            ]
          )
        ]
      end

      response = @service.query_searchanalytic(@site_url, request)

      return [] unless response.rows

      low_ctr = response.rows.filter_map do |row|
        impressions = row.impressions
        ctr = row.ctr

        next unless impressions >= min_impressions && ctr < ctr_threshold

        target_ctr = 0.05
        potential_clicks = (impressions * target_ctr).to_i
        missed_clicks = potential_clicks - row.clicks

        {
          url: row.keys[0],
          impressions: impressions,
          clicks: row.clicks,
          ctr: (ctr * 100).round(2),
          avg_position: row.position.round(1),
          potential_clicks: potential_clicks,
          missed_clicks: missed_clicks,
          priority: missed_clicks > 50 ? 'high' : 'medium'
        }
      end

      low_ctr.sort_by { |p| -p[:missed_clicks] }
    end

    # Find queries gaining traction (rising impressions)
    #
    # @param days_recent [Integer] Recent period to analyze
    # @param days_comparison [Integer] Previous period to compare against
    # @param min_impressions [Integer] Minimum impressions in recent period
    # @return [Array<Hash>] Trending queries
    def get_trending_queries(days_recent: 7, days_comparison: 30, min_impressions: 20)
      recent_end = Date.today.to_s
      recent_start = (Date.today - days_recent).to_s
      comparison_end = (Date.today - days_recent).to_s
      comparison_start = (Date.today - days_comparison).to_s

      recent_request = SearchConsole::SearchAnalyticsQueryRequest.new(
        start_date: recent_start,
        end_date: recent_end,
        dimensions: ['query'],
        row_limit: 1000
      )

      recent_response = @service.query_searchanalytic(@site_url, recent_request)

      comparison_request = SearchConsole::SearchAnalyticsQueryRequest.new(
        start_date: comparison_start,
        end_date: comparison_end,
        dimensions: ['query'],
        row_limit: 1000
      )

      comparison_response = @service.query_searchanalytic(@site_url, comparison_request)

      comparison_lookup = (comparison_response.rows || []).to_h { |row| [row.keys[0], row.impressions] }

      trending = (recent_response.rows || []).filter_map do |row|
        query = row.keys[0]
        recent_impressions = row.impressions

        next if recent_impressions < min_impressions

        previous_impressions = comparison_lookup[query] || 0
        change_percent = if previous_impressions.positive?
                           ((recent_impressions - previous_impressions).to_f / previous_impressions) * 100
                         else
                           100
                         end

        next unless change_percent > 20

        {
          query: query,
          recent_impressions: recent_impressions,
          previous_impressions: previous_impressions,
          change_percent: change_percent.round(1),
          clicks: row.clicks,
          position: row.position.round(1)
        }
      end

      trending.sort_by { |t| -t[:change_percent] }
    end

    # Track keyword position changes
    #
    # @param days_recent [Integer] Recent period
    # @param days_comparison [Integer] Previous period to compare
    # @return [Hash] Hash with 'improved', 'declined', and 'stable' lists
    def get_position_changes(days_recent: 7, days_comparison: 30)
      recent_data = get_keyword_positions(days: days_recent)
      comparison_data = get_keyword_positions(days: days_comparison)

      comparison_lookup = comparison_data.to_h { |kw| [kw[:keyword], kw[:position]] }

      improved = []
      declined = []
      stable = []

      recent_data.each do |kw|
        keyword = kw[:keyword]
        current_pos = kw[:position]
        previous_pos = comparison_lookup[keyword]

        next unless previous_pos

        position_change = previous_pos - current_pos

        result = kw.merge(
          previous_position: previous_pos,
          position_change: position_change.round(1)
        )

        if position_change >= 2
          improved << result
        elsif position_change <= -2
          declined << result
        else
          stable << result
        end
      end

      {
        improved: improved.sort_by { |r| -r[:position_change] },
        declined: declined.sort_by { |r| r[:position_change] },
        stable: stable
      }
    end

    private

    # Calculate commercial intent score for a keyword
    #
    # @param keyword [String] Keyword to analyze
    # @return [Float] Score between 0.1 (informational) and 3.0 (transactional)
    def calculate_commercial_intent(keyword)
      keyword = keyword.downcase

      # Check for low intent first (these override everything)
      return 0.1 if LOW_INTENT_TERMS.any? { |term| keyword.include?(term) }

      # Check for high intent
      return 3.0 if HIGH_INTENT_TERMS.any? { |term| keyword.include?(term) }

      # Check for medium-high intent
      return 2.0 if MEDIUM_HIGH_INTENT.any? { |term| keyword.include?(term) }

      # Check for medium intent
      return 1.0 if MEDIUM_INTENT.any? { |term| keyword.include?(term) }

      # Default: low-medium intent
      0.5
    end

    # Get human-readable intent category
    #
    # @param score [Float] Commercial intent score
    # @return [String] Category name
    def get_intent_category(score)
      if score >= 2.5
        'Transactional'
      elsif score >= 1.5
        'Commercial Investigation'
      elsif score >= 0.8
        'Informational (Relevant)'
      else
        'Informational (Low Value)'
      end
    end
  end
end
