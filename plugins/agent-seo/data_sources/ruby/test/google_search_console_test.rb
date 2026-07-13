# frozen_string_literal: true

require_relative 'test_helper'
require 'google/apis/searchconsole_v1'
require 'minitest/mock'

class GoogleSearchConsoleTest < Minitest::Test
  SearchConsole = Google::Apis::SearchconsoleV1

  def setup
    @credentials_path = create_temp_credentials_file
    ENV['GSC_SITE_URL'] = 'https://example.com'
    ENV['GSC_CREDENTIALS_PATH'] = @credentials_path
  end

  def teardown
    File.delete(@credentials_path) if @credentials_path && File.exist?(@credentials_path)
    ENV.delete('GSC_SITE_URL')
    ENV.delete('GSC_CREDENTIALS_PATH')
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

    file = Tempfile.new(['gsc_credentials', '.json'])
    file.write(credentials.to_json)
    file.close
    file.path
  end

  # Helper to create mock query response
  def create_mock_query_response(rows_data)
    response = SearchConsole::SearchAnalyticsQueryResponse.new

    response.rows = rows_data.map do |row|
      r = SearchConsole::ApiDataRow.new
      r.keys = row[:keys]
      r.clicks = row[:clicks]
      r.impressions = row[:impressions]
      r.ctr = row[:ctr]
      r.position = row[:position]
      r
    end

    response
  end

  # Helper to create a mock service
  def create_mock_service
    Minitest::Mock.new
  end

  # Helper to create client with mock service
  def create_client_with_mock_service(mock_service)
    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleSearchConsole.new
      # Replace the service with our mock
      client.instance_variable_set(:@service, mock_service)
      client
    end
  end

  # Initialization tests
  def test_initialization_with_credentials
    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleSearchConsole.new
      assert_instance_of AgentSeo::GoogleSearchConsole, client
      assert_equal 'https://example.com', client.site_url
    end
  end

  def test_initialization_raises_without_site_url
    ENV.delete('GSC_SITE_URL')

    assert_raises(AgentSeo::ConfigurationError) do
      AgentSeo::GoogleSearchConsole.new
    end
  end

  def test_initialization_raises_without_credentials_file
    ENV['GSC_CREDENTIALS_PATH'] = '/nonexistent/path.json'

    assert_raises(AgentSeo::ConfigurationError) do
      AgentSeo::GoogleSearchConsole.new
    end
  end

  def test_initialization_with_explicit_parameters
    Google::Auth::ServiceAccountCredentials.stub :make_creds, mock_authorizer do
      client = AgentSeo::GoogleSearchConsole.new(
        site_url: 'https://other-site.com',
        credentials_path: @credentials_path
      )
      assert_equal 'https://other-site.com', client.site_url
    end
  end

  # get_keyword_positions tests
  def test_get_keyword_positions_returns_keyword_data
    mock_response = create_mock_query_response([
      { keys: ['podcast hosting'], clicks: 150, impressions: 5000, ctr: 0.03, position: 8.5 },
      { keys: ['best podcast host'], clicks: 80, impressions: 3000, ctr: 0.027, position: 12.3 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_keyword_positions(days: 30, limit: 100)

    assert_kind_of Array, result
    assert_equal 2, result.size

    # Should be sorted by impressions descending
    first = result.first
    assert_equal 'podcast hosting', first[:keyword]
    assert_equal 150, first[:clicks]
    assert_equal 5000, first[:impressions]
    assert_equal 0.03, first[:ctr]
    assert_equal 8.5, first[:position]

    mock_service.verify
  end

  def test_get_keyword_positions_returns_empty_when_no_rows
    mock_response = SearchConsole::SearchAnalyticsQueryResponse.new
    mock_response.rows = nil

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_keyword_positions

    assert_empty result
    mock_service.verify
  end

  # get_quick_wins tests
  def test_get_quick_wins_identifies_opportunities
    mock_response = create_mock_query_response([
      { keys: ['podcast hosting pricing'], clicks: 20, impressions: 800, ctr: 0.025, position: 12.5 },
      { keys: ['how to podcast'], clicks: 50, impressions: 2000, ctr: 0.025, position: 15.0 },
      { keys: ['podcast tips'], clicks: 100, impressions: 600, ctr: 0.167, position: 5.0 }, # Not a quick win (pos < 11)
      { keys: ['podcast guide'], clicks: 5, impressions: 30, ctr: 0.167, position: 14.0 } # Not a quick win (impressions < 50)
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_quick_wins(days: 30, position_min: 11, position_max: 20, min_impressions: 50)

    assert_kind_of Array, result
    assert_equal 2, result.size # Only the two that meet criteria

    # Verify commercial intent scoring
    first = result.first
    assert first.key?(:commercial_intent)
    assert first.key?(:commercial_intent_category)
    assert first.key?(:opportunity_score)
    assert first.key?(:priority)

    # Verify priority assignment
    high_priority_keywords = result.select { |kw| kw[:priority] == 'high' }
    high_priority_keywords.each do |kw|
      assert_operator kw[:position], :<=, 15, 'High priority should have position <= 15'
    end

    mock_service.verify
  end

  def test_get_quick_wins_with_commercial_intent_prioritization
    mock_response = create_mock_query_response([
      { keys: ['podcast pricing comparison'], clicks: 30, impressions: 500, ctr: 0.06, position: 12.0 },
      { keys: ['what is a podcast'], clicks: 40, impressions: 600, ctr: 0.067, position: 12.0 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_quick_wins(prioritize_commercial: true)

    assert_kind_of Array, result

    # "pricing comparison" should have higher commercial intent score
    pricing_kw = result.find { |kw| kw[:keyword].include?('pricing') }
    what_is_kw = result.find { |kw| kw[:keyword].include?('what is') }

    if pricing_kw && what_is_kw
      assert_operator pricing_kw[:commercial_intent], :>, what_is_kw[:commercial_intent],
                      'Pricing keyword should have higher commercial intent'
    end

    mock_service.verify
  end

  # get_page_performance tests
  def test_get_page_performance_returns_page_data
    page_response = create_mock_query_response([
      { keys: ['https://example.com/blog/podcast-hosting'], clicks: 200, impressions: 8000, ctr: 0.025, position: 9.2 }
    ])

    keywords_response = create_mock_query_response([
      { keys: ['podcast hosting'], clicks: 100, impressions: 4000, ctr: 0.025, position: 8.5 },
      { keys: ['best podcast host'], clicks: 50, impressions: 2000, ctr: 0.025, position: 10.0 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, page_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])
    mock_service.expect(:query_searchanalytic, keywords_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_page_performance('/blog/podcast-hosting', days: 30)

    assert_kind_of Hash, result
    assert result[:url].include?('podcast-hosting')
    assert_equal 200, result[:clicks]
    assert_equal 8000, result[:impressions]
    assert_equal 2.5, result[:ctr] # ctr * 100
    assert_equal 9.2, result[:avg_position]

    # Check top keywords
    assert result.key?(:top_keywords)
    assert_kind_of Array, result[:top_keywords]
    assert_equal 2, result[:top_keywords].size

    mock_service.verify
  end

  def test_get_page_performance_handles_no_data
    mock_response = SearchConsole::SearchAnalyticsQueryResponse.new
    mock_response.rows = nil

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_page_performance('/nonexistent-page')

    assert_kind_of Hash, result
    assert result.key?(:error)
    assert_equal 'No data found', result[:error]

    mock_service.verify
  end

  # get_low_ctr_pages tests
  def test_get_low_ctr_pages_identifies_opportunities
    mock_response = create_mock_query_response([
      { keys: ['https://example.com/blog/good-article'], clicks: 50, impressions: 1000, ctr: 0.05, position: 5.0 },
      { keys: ['https://example.com/blog/bad-ctr'], clicks: 10, impressions: 1000, ctr: 0.01, position: 6.0 },
      { keys: ['https://example.com/blog/small-page'], clicks: 5, impressions: 50, ctr: 0.1, position: 3.0 } # Under threshold
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_low_ctr_pages(days: 30, ctr_threshold: 0.03, min_impressions: 100)

    assert_kind_of Array, result
    assert_equal 1, result.size # Only bad-ctr meets criteria

    page = result.first
    assert page[:url].include?('bad-ctr')
    assert_equal 1000, page[:impressions]
    assert_equal 10, page[:clicks]
    assert_equal 1.0, page[:ctr] # ctr * 100
    assert page.key?(:potential_clicks)
    assert page.key?(:missed_clicks)
    assert_operator page[:missed_clicks], :>, 0

    mock_service.verify
  end

  # get_trending_queries tests
  def test_get_trending_queries_identifies_rising_queries
    recent_response = create_mock_query_response([
      { keys: ['trending keyword'], clicks: 50, impressions: 500, ctr: 0.1, position: 8.0 },
      { keys: ['stable keyword'], clicks: 30, impressions: 100, ctr: 0.3, position: 5.0 }
    ])

    comparison_response = create_mock_query_response([
      { keys: ['trending keyword'], clicks: 20, impressions: 200, ctr: 0.1, position: 10.0 },
      { keys: ['stable keyword'], clicks: 25, impressions: 90, ctr: 0.28, position: 6.0 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, recent_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])
    mock_service.expect(:query_searchanalytic, comparison_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_trending_queries(days_recent: 7, days_comparison: 30, min_impressions: 20)

    assert_kind_of Array, result

    # Trending keyword: 500 vs 200 = 150% increase
    # Stable keyword: 100 vs 90 = ~11% increase (borderline)
    trending = result.find { |q| q[:query] == 'trending keyword' }
    assert trending, 'Expected to find trending keyword'
    assert_equal 500, trending[:recent_impressions]
    assert_equal 200, trending[:previous_impressions]
    assert_operator trending[:change_percent], :>, 100

    mock_service.verify
  end

  # get_position_changes tests
  def test_get_position_changes_categorizes_correctly
    recent_response = create_mock_query_response([
      { keys: ['improved keyword'], clicks: 100, impressions: 1000, ctr: 0.1, position: 5.0 },
      { keys: ['declined keyword'], clicks: 50, impressions: 800, ctr: 0.0625, position: 15.0 },
      { keys: ['stable keyword'], clicks: 70, impressions: 900, ctr: 0.078, position: 8.0 }
    ])

    comparison_response = create_mock_query_response([
      { keys: ['improved keyword'], clicks: 80, impressions: 900, ctr: 0.089, position: 10.0 },
      { keys: ['declined keyword'], clicks: 80, impressions: 1200, ctr: 0.067, position: 8.0 },
      { keys: ['stable keyword'], clicks: 65, impressions: 880, ctr: 0.074, position: 8.5 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, recent_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])
    mock_service.expect(:query_searchanalytic, comparison_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_position_changes(days_recent: 7, days_comparison: 30)

    assert_kind_of Hash, result
    assert result.key?(:improved)
    assert result.key?(:declined)
    assert result.key?(:stable)

    # Improved: position went from 10 to 5 (improvement of 5)
    improved = result[:improved].find { |kw| kw[:keyword] == 'improved keyword' }
    assert improved, 'Expected improved keyword in improved list'
    assert_equal 5.0, improved[:position_change]

    # Declined: position went from 8 to 15 (decline of -7)
    declined = result[:declined].find { |kw| kw[:keyword] == 'declined keyword' }
    assert declined, 'Expected declined keyword in declined list'
    assert_equal(-7.0, declined[:position_change])

    mock_service.verify
  end

  # Commercial intent calculation tests
  def test_commercial_intent_high_for_pricing_keywords
    mock_response = create_mock_query_response([
      { keys: ['podcast hosting pricing'], clicks: 20, impressions: 500, ctr: 0.04, position: 12.0 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_quick_wins

    kw = result.first
    assert_equal 3.0, kw[:commercial_intent], 'Pricing keyword should have high commercial intent'
    assert_equal 'Transactional', kw[:commercial_intent_category]

    mock_service.verify
  end

  def test_commercial_intent_low_for_celebrity_keywords
    mock_response = create_mock_query_response([
      { keys: ['pewdiepie net worth'], clicks: 20, impressions: 500, ctr: 0.04, position: 12.0 }
    ])

    mock_service = create_mock_service
    mock_service.expect(:query_searchanalytic, mock_response, ['https://example.com', SearchConsole::SearchAnalyticsQueryRequest])

    client = create_client_with_mock_service(mock_service)
    result = client.get_quick_wins

    kw = result.first
    assert_equal 0.1, kw[:commercial_intent], 'Celebrity keyword should have low commercial intent'
    assert_equal 'Informational (Low Value)', kw[:commercial_intent_category]

    mock_service.verify
  end

  private

  def mock_authorizer
    Minitest::Mock.new.expect(:nil?, false)
  end
end
