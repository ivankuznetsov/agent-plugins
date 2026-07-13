# frozen_string_literal: true

require_relative 'test_helper'
require 'google/apis/analyticsdata_v1beta'
require 'minitest/mock'

class GoogleAnalyticsTest < Minitest::Test
  AnalyticsData = Google::Apis::AnalyticsdataV1beta

  def setup
    @credentials_path = create_temp_credentials_file
    ENV['GA4_PROPERTY_ID'] = '123456789'
    ENV['GA4_CREDENTIALS_PATH'] = @credentials_path
  end

  def teardown
    File.delete(@credentials_path) if @credentials_path && File.exist?(@credentials_path)
    ENV.delete('GA4_PROPERTY_ID')
    ENV.delete('GA4_CREDENTIALS_PATH')
  end

  # Helper to create a temporary credentials file
  def create_temp_credentials_file
    require 'tempfile'
    credentials = {
      'type' => 'service_account',
      'project_id' => 'test-project',
      'private_key_id' => 'test-key-id',
      'private_key' => OpenSSL::PKey::RSA.new(2048).to_pem,
      'client_email' => 'test@test-project.iam.gserviceaccount.com',
      'client_id' => '123456789',
      'auth_uri' => 'https://accounts.google.com/o/oauth2/auth',
      'token_uri' => 'https://oauth2.googleapis.com/token'
    }

    file = Tempfile.new(['ga4_credentials', '.json'])
    file.write(credentials.to_json)
    file.close
    file.path
  end

  # Helper to create mock report response
  def create_mock_report_response(rows_data)
    response = AnalyticsData::RunReportResponse.new

    response.rows = rows_data.map do |row|
      r = AnalyticsData::Row.new
      r.dimension_values = row[:dimensions].map { |v| AnalyticsData::DimensionValue.new(value: v) }
      r.metric_values = row[:metrics].map { |v| AnalyticsData::MetricValue.new(value: v.to_s) }
      r
    end

    response
  end

  # Initialization tests
  def test_initialization_with_credentials
    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new
      assert_instance_of AgentSeo::GoogleAnalytics, client
      assert_equal '123456789', client.property_id
    end
  end

  def test_initialization_raises_without_property_id
    ENV.delete('GA4_PROPERTY_ID')

    assert_raises(AgentSeo::ConfigurationError) do
      AgentSeo::GoogleAnalytics.new
    end
  end

  def test_initialization_raises_without_credentials_file
    ENV['GA4_CREDENTIALS_PATH'] = '/nonexistent/path.json'

    assert_raises(AgentSeo::ConfigurationError) do
      AgentSeo::GoogleAnalytics.new
    end
  end

  def test_initialization_with_explicit_parameters
    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new(
        property_id: '987654321',
        credentials_path: @credentials_path
      )
      assert_equal '987654321', client.property_id
    end
  end

  # get_top_pages tests
  def test_get_top_pages_returns_page_data
    mock_response = create_mock_report_response([
      {
        dimensions: ['/blog/podcast-hosting', 'Best Podcast Hosting Guide'],
        metrics: [1500, 1200, 125.5, 0.35, 0.65]
      },
      {
        dimensions: ['/blog/start-podcast', 'How to Start a Podcast'],
        metrics: [1200, 950, 180.2, 0.28, 0.72]
      }
    ])

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, mock_response do
        result = client.get_top_pages(days: 30, limit: 10, path_filter: '/blog/')

        assert_kind_of Array, result
        assert_equal 2, result.size

        first_page = result.first
        assert_equal '/blog/podcast-hosting', first_page[:path]
        assert_equal 'Best Podcast Hosting Guide', first_page[:title]
        assert_equal 1500, first_page[:pageviews]
        assert_equal 1200, first_page[:sessions]
        assert_in_delta 125.5, first_page[:avg_session_duration], 0.1
        assert_in_delta 0.35, first_page[:bounce_rate], 0.01
        assert_in_delta 0.65, first_page[:engagement_rate], 0.01
      end
    end
  end

  def test_get_top_pages_returns_empty_when_no_rows
    mock_response = AnalyticsData::RunReportResponse.new
    mock_response.rows = nil

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, mock_response do
        result = client.get_top_pages

        assert_empty result
      end
    end
  end

  # get_page_trends tests
  def test_get_page_trends_returns_trend_data
    mock_response = create_mock_report_response([
      { dimensions: ['202501'], metrics: [100, 80, 120.5] },
      { dimensions: ['202502'], metrics: [110, 90, 125.2] },
      { dimensions: ['202503'], metrics: [150, 120, 130.0] },
      { dimensions: ['202504'], metrics: [180, 145, 135.5] }
    ])

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, mock_response do
        result = client.get_page_trends('/blog/test-article', days: 90)

        assert_kind_of Hash, result
        assert_equal '/blog/test-article', result[:url]
        assert_kind_of Array, result[:timeline]
        assert_equal 4, result[:timeline].size

        # Verify trend calculation
        assert_includes %w[rising declining stable unknown], result[:trend_direction]
        assert_kind_of Numeric, result[:trend_percent]
        assert_equal 540, result[:total_pageviews] # 100+110+150+180
      end
    end
  end

  def test_get_page_trends_handles_rising_trend
    # Create data where recent > older by >10%
    mock_response = create_mock_report_response([
      { dimensions: ['week1'], metrics: [100, 80, 120.0] },
      { dimensions: ['week2'], metrics: [100, 80, 120.0] },
      { dimensions: ['week3'], metrics: [100, 80, 120.0] },
      { dimensions: ['week4'], metrics: [100, 80, 120.0] },
      { dimensions: ['week5'], metrics: [200, 160, 140.0] },
      { dimensions: ['week6'], metrics: [200, 160, 140.0] },
      { dimensions: ['week7'], metrics: [200, 160, 140.0] },
      { dimensions: ['week8'], metrics: [200, 160, 140.0] }
    ])

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, mock_response do
        result = client.get_page_trends('/blog/test')

        assert_equal 'rising', result[:trend_direction]
        assert_operator result[:trend_percent], :>, 10
      end
    end
  end

  # get_conversions tests
  def test_get_conversions_returns_conversion_data
    mock_response = create_mock_report_response([
      {
        dimensions: ['/blog/pricing-guide', 'Pricing Guide'],
        metrics: [1000, 25.0, 500.00]
      }
    ])

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, mock_response do
        result = client.get_conversions(days: 30)

        assert_kind_of Array, result
        assert_equal 1, result.size

        conversion = result.first
        assert_equal '/blog/pricing-guide', conversion[:path]
        assert_equal 1000, conversion[:pageviews]
        assert_in_delta 25.0, conversion[:conversions], 0.1
        assert_in_delta 2.5, conversion[:conversion_rate], 0.1 # 25/1000*100
        assert_in_delta 500.0, conversion[:revenue], 0.1
      end
    end
  end

  # get_traffic_sources tests
  def test_get_traffic_sources_returns_source_breakdown
    mock_response = create_mock_report_response([
      { dimensions: ['Organic Search'], metrics: [500, 600, 0.72] },
      { dimensions: ['Direct'], metrics: [300, 350, 0.65] },
      { dimensions: ['Social'], metrics: [200, 250, 0.58] }
    ])

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, mock_response do
        result = client.get_traffic_sources(days: 30)

        assert_kind_of Array, result
        assert_equal 3, result.size

        organic = result.find { |s| s[:source] == 'Organic Search' }
        assert_equal 500, organic[:sessions]
        assert_equal 600, organic[:pageviews]
        assert_in_delta 0.72, organic[:engagement_rate], 0.01
      end
    end
  end

  # get_declining_pages tests
  def test_get_declining_pages_identifies_declining_content
    recent_response = create_mock_report_response([
      { dimensions: ['/blog/old-article', 'Old Article'], metrics: [100, 80, 90.0, 0.4, 0.6] },
      { dimensions: ['/blog/stable-article', 'Stable Article'], metrics: [500, 400, 120.0, 0.3, 0.7] }
    ])

    previous_response = create_mock_report_response([
      { dimensions: ['/blog/old-article', 'Old Article'], metrics: [200, 160, 100.0, 0.35, 0.65] },
      { dimensions: ['/blog/stable-article', 'Stable Article'], metrics: [480, 380, 115.0, 0.32, 0.68] }
    ])

    call_count = 0

    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleAnalytics.new

      client.client.stub :run_property_report, ->(*_args) {
        call_count += 1
        call_count == 1 ? recent_response : previous_response
      } do
        result = client.get_declining_pages(comparison_days: 30, threshold_percent: -20.0)

        assert_kind_of Array, result

        # Old article declined 50% (200 -> 100)
        declining = result.find { |p| p[:path] == '/blog/old-article' }
        assert declining, 'Expected to find declining article'
        assert_equal 200, declining[:previous_pageviews]
        assert_in_delta(-50.0, declining[:change_percent], 1.0)
        assert_equal 'high', declining[:priority] # >40% drop
      end
    end
  end

  private

  def mock_authorizer
    Minitest::Mock.new.expect(:nil?, false)
  end
end
