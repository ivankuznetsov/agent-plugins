# frozen_string_literal: true

require_relative 'test_helper'
require 'webmock/minitest'

class DataForSeoTest < Minitest::Test
  def setup
    ENV['DATAFORSEO_LOGIN'] = 'test_login'
    ENV['DATAFORSEO_PASSWORD'] = 'test_password'
    ENV['DATAFORSEO_BASE_URL'] = 'https://api.dataforseo.com'

    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def teardown
    WebMock.reset!
    ENV.delete('DATAFORSEO_LOGIN')
    ENV.delete('DATAFORSEO_PASSWORD')
    ENV.delete('DATAFORSEO_BASE_URL')
  end

  # Helper to load fixtures
  def fixture(filename)
    File.read(File.join(__dir__, 'fixtures', filename))
  end

  # Initialization tests
  def test_initialization_with_credentials
    client = AgentSeo::DataForSeo.new
    assert_instance_of AgentSeo::DataForSeo, client
    assert_equal 'https://api.dataforseo.com', client.base_url
  end

  def test_initialization_with_explicit_credentials
    client = AgentSeo::DataForSeo.new(login: 'custom_login', password: 'custom_password')
    assert_instance_of AgentSeo::DataForSeo, client
  end

  def test_initialization_raises_without_credentials
    ENV.delete('DATAFORSEO_LOGIN')
    ENV.delete('DATAFORSEO_PASSWORD')

    assert_raises(AgentSeo::ConfigurationError) do
      AgentSeo::DataForSeo.new
    end
  end

  def test_initialization_raises_with_partial_credentials
    ENV.delete('DATAFORSEO_PASSWORD')

    assert_raises(AgentSeo::ConfigurationError) do
      AgentSeo::DataForSeo.new
    end
  end

  # get_rankings tests
  def test_get_rankings_parses_response
    stub_request(:post, 'https://api.dataforseo.com/v3/serp/google/organic/live/advanced')
      .to_return(
        status: 200,
        body: fixture('dataforseo_rankings.json'),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_rankings(domain: 'example.com', keywords: ['podcast hosting'])

    assert_kind_of Array, result
    assert_equal 1, result.size

    ranking = result.first
    assert_equal 'podcast hosting', ranking[:keyword]
    assert_equal 'example.com', ranking[:domain]
    assert_equal 3, ranking[:position]
    assert_equal 'https://www.example.com/podcast-hosting', ranking[:url]
    assert ranking[:ranking]
    assert_equal 12_100, ranking[:search_volume]
    assert_equal 5.25, ranking[:cpc]
  end

  def test_get_rankings_returns_empty_on_api_error
    stub_request(:post, 'https://api.dataforseo.com/v3/serp/google/organic/live/advanced')
      .to_return(
        status: 200,
        body: { status_code: 50_000, status_message: 'Internal Error' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_rankings(domain: 'example.com', keywords: ['test'])

    assert_empty result, 'Expected empty array on API error status'
  end

  def test_get_rankings_handles_domain_not_ranking
    response = JSON.parse(fixture('dataforseo_rankings.json'))
    # Remove the example.com result so domain is not ranking
    response['tasks'][0]['result'][0]['items'] = response['tasks'][0]['result'][0]['items'].reject do |item|
      item['domain']&.include?('example.com')
    end

    stub_request(:post, 'https://api.dataforseo.com/v3/serp/google/organic/live/advanced')
      .to_return(
        status: 200,
        body: response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_rankings(domain: 'notfound.com', keywords: ['podcast hosting'])

    assert_equal 1, result.size
    ranking = result.first
    assert_nil ranking[:position]
    assert_nil ranking[:url]
    refute ranking[:ranking]
  end

  def test_get_rankings_handles_multiple_keywords
    stub_request(:post, 'https://api.dataforseo.com/v3/serp/google/organic/live/advanced')
      .to_return(
        status: 200,
        body: fixture('dataforseo_rankings.json'),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_rankings(domain: 'example.com', keywords: ['podcast hosting', 'podcast equipment'])

    # The stub returns same response for all, but validates the call works
    assert_kind_of Array, result
  end

  # get_serp_data tests
  def test_get_serp_data_parses_response
    stub_request(:post, 'https://api.dataforseo.com/v3/serp/google/organic/live/advanced')
      .to_return(
        status: 200,
        body: fixture('dataforseo_serp_data.json'),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_serp_data('how to start a podcast')

    assert_kind_of Hash, result
    assert_equal 'how to start a podcast', result[:keyword]
    assert_equal 33_100, result[:search_volume]
    assert_equal 3.50, result[:cpc]
    assert_equal 0.75, result[:competition]

    assert_kind_of Array, result[:organic_results]
    assert_operator result[:organic_results].size, :>=, 1

    first_result = result[:organic_results].first
    assert_equal 1, first_result[:position]
    assert_equal 'buzzsprout.com', first_result[:domain]
    assert first_result[:url].include?('buzzsprout.com')

    assert_kind_of Array, result[:features]
    assert_includes result[:features], 'people_also_ask'
  end

  def test_get_serp_data_returns_error_on_api_failure
    stub_request(:post, 'https://api.dataforseo.com/v3/serp/google/organic/live/advanced')
      .to_return(
        status: 200,
        body: { status_code: 50_000, status_message: 'Error' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_serp_data('test keyword')

    assert_kind_of Hash, result
    assert result.key?(:error)
    assert_equal 'API request failed', result[:error]
  end

  # get_keyword_ideas tests
  def test_get_keyword_ideas_parses_response
    stub_request(:post, 'https://api.dataforseo.com/v3/dataforseo_labs/google/related_keywords/live')
      .to_return(
        status: 200,
        body: fixture('dataforseo_keyword_ideas.json'),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_keyword_ideas('podcast')

    assert_kind_of Array, result
    assert_operator result.size, :>=, 1

    # Results should be sorted by search volume descending
    first = result.first
    assert first.key?(:keyword)
    assert first.key?(:search_volume)
    assert first.key?(:cpc)
    assert first.key?(:competition)

    # Verify sort order (highest search volume first)
    search_volumes = result.map { |kw| kw[:search_volume] || 0 }
    assert_equal search_volumes.sort.reverse, search_volumes, 'Keywords should be sorted by search volume descending'
  end

  def test_get_keyword_ideas_returns_empty_on_error
    stub_request(:post, 'https://api.dataforseo.com/v3/dataforseo_labs/google/related_keywords/live')
      .to_return(
        status: 200,
        body: { status_code: 40_000, status_message: 'Bad Request' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_keyword_ideas('test')

    assert_empty result
  end

  # get_domain_metrics tests
  def test_get_domain_metrics_parses_response
    stub_request(:post, 'https://api.dataforseo.com/v3/dataforseo_labs/google/domain_metrics/live')
      .to_return(
        status: 200,
        body: fixture('dataforseo_domain_metrics.json'),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_domain_metrics('example.com')

    assert_kind_of Hash, result
    assert_equal 'example.com', result[:domain]
    assert_equal 15_420, result[:organic_keywords]
    assert_equal 125_000, result[:organic_traffic]
    assert_equal 45, result[:domain_rank]
    assert_equal 892_456, result[:backlinks]
  end

  def test_get_domain_metrics_returns_empty_on_error
    stub_request(:post, 'https://api.dataforseo.com/v3/dataforseo_labs/google/domain_metrics/live')
      .to_return(
        status: 200,
        body: { status_code: 50_000, status_message: 'Error' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    client = AgentSeo::DataForSeo.new
    result = client.get_domain_metrics('example.com')

    assert_empty result
  end

  # HTTP error handling tests
  def test_handles_http_500_error
    stub_request(:post, /dataforseo/)
      .to_return(status: 500, body: 'Internal Server Error')

    client = AgentSeo::DataForSeo.new

    # The Faraday JSON response middleware should handle non-JSON responses
    # This tests that the code handles the edge case gracefully
    result = client.get_rankings(domain: 'example.com', keywords: ['test'])
    assert_empty result
  end

  def test_handles_network_timeout
    stub_request(:post, /dataforseo/)
      .to_timeout

    client = AgentSeo::DataForSeo.new

    assert_raises(Faraday::ConnectionFailed) do
      client.get_rankings(domain: 'example.com', keywords: ['test'])
    end
  end
end
