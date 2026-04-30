# frozen_string_literal: true

require 'google/apis/analyticsdata_v1beta'
require 'googleauth'
require 'date'

module AgentSeo
  # Google Analytics 4 Data Integration
  # Fetches traffic, engagement, and conversion data from GA4 properties.
  class GoogleAnalytics
    AnalyticsData = Google::Apis::AnalyticsdataV1beta

    attr_reader :property_id, :client

    # Initialize GA4 client
    #
    # @param property_id [String] GA4 property ID (defaults to env var GA4_PROPERTY_ID)
    # @param credentials_path [String] Path to credentials JSON (defaults to env var)
    def initialize(property_id: nil, credentials_path: nil)
      @property_id = property_id || ENV.fetch('GA4_PROPERTY_ID', nil)
      credentials_path ||= ENV.fetch('GA4_CREDENTIALS_PATH', nil)

      raise ConfigurationError, 'GA4_PROPERTY_ID must be provided or set in environment' unless @property_id
      raise ConfigurationError, "Credentials file not found: #{credentials_path}" unless credentials_path && File.exist?(credentials_path)

      scope = ['https://www.googleapis.com/auth/analytics.readonly']
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(credentials_path),
        scope: scope
      )

      @client = AnalyticsData::AnalyticsDataService.new
      @client.authorization = authorizer
    end

    # Get top performing pages by pageviews
    #
    # @param days [Integer] Number of days to look back
    # @param limit [Integer] Number of results to return
    # @param path_filter [String] Filter pages by path (e.g., "/blog/")
    # @return [Array<Hash>] List of pages with metrics
    def get_top_pages(days: 30, limit: 20, path_filter: '/blog/')
      request = AnalyticsData::RunReportRequest.new(
        property: "properties/#{@property_id}",
        date_ranges: [
          AnalyticsData::DateRange.new(start_date: "#{days}daysAgo", end_date: 'today')
        ],
        dimensions: [
          AnalyticsData::Dimension.new(name: 'pagePath'),
          AnalyticsData::Dimension.new(name: 'pageTitle')
        ],
        metrics: [
          AnalyticsData::Metric.new(name: 'screenPageViews'),
          AnalyticsData::Metric.new(name: 'sessions'),
          AnalyticsData::Metric.new(name: 'averageSessionDuration'),
          AnalyticsData::Metric.new(name: 'bounceRate'),
          AnalyticsData::Metric.new(name: 'engagementRate')
        ],
        limit: limit,
        order_bys: [
          AnalyticsData::OrderBy.new(
            metric: AnalyticsData::MetricOrderBy.new(metric_name: 'screenPageViews'),
            desc: true
          )
        ]
      )

      if path_filter
        request.dimension_filter = AnalyticsData::FilterExpression.new(
          filter: AnalyticsData::Filter.new(
            field_name: 'pagePath',
            string_filter: AnalyticsData::StringFilter.new(
              match_type: 'CONTAINS',
              value: path_filter
            )
          )
        )
      end

      response = @client.run_property_report("properties/#{@property_id}", request)

      return [] unless response.rows

      response.rows.map do |row|
        {
          path: row.dimension_values[0].value,
          title: row.dimension_values[1].value,
          pageviews: row.metric_values[0].value.to_i,
          sessions: row.metric_values[1].value.to_i,
          avg_session_duration: row.metric_values[2].value.to_f,
          bounce_rate: row.metric_values[3].value.to_f,
          engagement_rate: row.metric_values[4].value.to_f
        }
      end
    end

    # Get traffic trends for a specific page
    #
    # @param url [String] Page path (e.g., "/blog/podcast-monetization")
    # @param days [Integer] Number of days to analyze
    # @param granularity [String] "day" or "week"
    # @return [Hash] Trend data with timeline
    def get_page_trends(url, days: 90, granularity: 'week')
      dimension_name = granularity == 'day' ? 'date' : 'week'

      request = AnalyticsData::RunReportRequest.new(
        property: "properties/#{@property_id}",
        date_ranges: [
          AnalyticsData::DateRange.new(start_date: "#{days}daysAgo", end_date: 'today')
        ],
        dimensions: [AnalyticsData::Dimension.new(name: dimension_name)],
        metrics: [
          AnalyticsData::Metric.new(name: 'screenPageViews'),
          AnalyticsData::Metric.new(name: 'sessions'),
          AnalyticsData::Metric.new(name: 'averageSessionDuration')
        ],
        dimension_filter: AnalyticsData::FilterExpression.new(
          filter: AnalyticsData::Filter.new(
            field_name: 'pagePath',
            string_filter: AnalyticsData::StringFilter.new(
              match_type: 'EXACT',
              value: url
            )
          )
        ),
        order_bys: [
          AnalyticsData::OrderBy.new(
            dimension: AnalyticsData::DimensionOrderBy.new(dimension_name: dimension_name),
            desc: false
          )
        ]
      )

      response = @client.run_property_report("properties/#{@property_id}", request)

      timeline = (response.rows || []).map do |row|
        {
          period: row.dimension_values[0].value,
          pageviews: row.metric_values[0].value.to_i,
          sessions: row.metric_values[1].value.to_i,
          avg_duration: row.metric_values[2].value.to_f
        }
      end

      trend_direction, trend_percent = calculate_trend(timeline)

      {
        url: url,
        timeline: timeline,
        trend_direction: trend_direction,
        trend_percent: trend_percent.round(2),
        total_pageviews: timeline.sum { |t| t[:pageviews] }
      }
    end

    # Get conversion data by page
    #
    # @param days [Integer] Number of days to look back
    # @param path_filter [String] Filter pages by path
    # @return [Array<Hash>] Pages with conversion data
    def get_conversions(days: 30, path_filter: '/blog/')
      request = AnalyticsData::RunReportRequest.new(
        property: "properties/#{@property_id}",
        date_ranges: [
          AnalyticsData::DateRange.new(start_date: "#{days}daysAgo", end_date: 'today')
        ],
        dimensions: [
          AnalyticsData::Dimension.new(name: 'pagePath'),
          AnalyticsData::Dimension.new(name: 'pageTitle')
        ],
        metrics: [
          AnalyticsData::Metric.new(name: 'screenPageViews'),
          AnalyticsData::Metric.new(name: 'conversions'),
          AnalyticsData::Metric.new(name: 'totalRevenue')
        ],
        order_bys: [
          AnalyticsData::OrderBy.new(
            metric: AnalyticsData::MetricOrderBy.new(metric_name: 'conversions'),
            desc: true
          )
        ]
      )

      if path_filter
        request.dimension_filter = AnalyticsData::FilterExpression.new(
          filter: AnalyticsData::Filter.new(
            field_name: 'pagePath',
            string_filter: AnalyticsData::StringFilter.new(
              match_type: 'CONTAINS',
              value: path_filter
            )
          )
        )
      end

      response = @client.run_property_report("properties/#{@property_id}", request)

      return [] unless response.rows

      response.rows.map do |row|
        pageviews = row.metric_values[0].value.to_i
        conversions = row.metric_values[1].value.to_f

        {
          path: row.dimension_values[0].value,
          title: row.dimension_values[1].value,
          pageviews: pageviews,
          conversions: conversions,
          conversion_rate: pageviews.positive? ? (conversions / pageviews * 100) : 0,
          revenue: row.metric_values[2].value.to_f
        }
      end
    end

    # Get traffic source breakdown for a page or entire site
    #
    # @param url [String] Specific page path (optional, nil = all pages)
    # @param days [Integer] Number of days to analyze
    # @return [Array<Hash>] Traffic sources with metrics
    def get_traffic_sources(url: nil, days: 30)
      request = AnalyticsData::RunReportRequest.new(
        property: "properties/#{@property_id}",
        date_ranges: [
          AnalyticsData::DateRange.new(start_date: "#{days}daysAgo", end_date: 'today')
        ],
        dimensions: [AnalyticsData::Dimension.new(name: 'sessionDefaultChannelGroup')],
        metrics: [
          AnalyticsData::Metric.new(name: 'sessions'),
          AnalyticsData::Metric.new(name: 'screenPageViews'),
          AnalyticsData::Metric.new(name: 'engagementRate')
        ],
        order_bys: [
          AnalyticsData::OrderBy.new(
            metric: AnalyticsData::MetricOrderBy.new(metric_name: 'sessions'),
            desc: true
          )
        ]
      )

      if url
        request.dimension_filter = AnalyticsData::FilterExpression.new(
          filter: AnalyticsData::Filter.new(
            field_name: 'pagePath',
            string_filter: AnalyticsData::StringFilter.new(
              match_type: 'EXACT',
              value: url
            )
          )
        )
      end

      response = @client.run_property_report("properties/#{@property_id}", request)

      return [] unless response.rows

      response.rows.map do |row|
        {
          source: row.dimension_values[0].value,
          sessions: row.metric_values[0].value.to_i,
          pageviews: row.metric_values[1].value.to_i,
          engagement_rate: row.metric_values[2].value.to_f
        }
      end
    end

    # Identify pages with declining traffic
    #
    # @param comparison_days [Integer] Compare this many recent days vs previous period
    # @param threshold_percent [Float] Consider declining if drop exceeds this %
    # @param path_filter [String] Filter pages by path
    # @return [Array<Hash>] Declining pages with metrics
    def get_declining_pages(comparison_days: 30, threshold_percent: -20.0, path_filter: '/blog/')
      recent_pages = get_top_pages(days: comparison_days, limit: 100, path_filter: path_filter)
      previous_pages = get_top_pages(days: comparison_days * 2, limit: 100, path_filter: path_filter)

      previous_lookup = previous_pages.to_h { |p| [p[:path], p[:pageviews]] }

      declining = recent_pages.filter_map do |page|
        path = page[:path]
        recent_views = page[:pageviews]
        previous_views = previous_lookup[path] || 0

        next unless previous_views.positive?

        change_percent = ((recent_views - previous_views).to_f / previous_views) * 100

        next unless change_percent < threshold_percent

        page.merge(
          previous_pageviews: previous_views,
          change_percent: change_percent.round(2),
          priority: change_percent < -40 ? 'high' : 'medium'
        )
      end

      declining.sort_by { |p| p[:change_percent] }
    end

    private

    def calculate_trend(timeline)
      return ['unknown', 0] if timeline.length < 2

      recent_views = timeline.last(4).sum { |t| t[:pageviews] }
      older_views = timeline.first(4).sum { |t| t[:pageviews] }

      return ['stable', 0] unless older_views.positive?

      trend_percent = ((recent_views - older_views).to_f / older_views) * 100
      trend_direction = if trend_percent > 10
                          'rising'
                        elsif trend_percent < -10
                          'declining'
                        else
                          'stable'
                        end

      [trend_direction, trend_percent]
    end
  end
end
