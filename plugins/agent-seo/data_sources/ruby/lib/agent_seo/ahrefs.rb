# frozen_string_literal: true

require 'faraday'
require 'json'
require 'date'

module AgentSeo
  # Ahrefs API Client
  # Provides access to Ahrefs SEO data including domain rating, backlinks, and organic keywords.
  #
  # Requires Enterprise plan ($1,249+/month) for API access.
  # API documentation: https://ahrefs.com/api
  class Ahrefs
    BASE_URL = 'https://api.ahrefs.com/v3'

    # Initialize the Ahrefs client
    #
    # @param api_key [String, nil] Ahrefs API key (defaults to AHREFS_API_KEY env var)
    # @raise [ConfigurationError] if API key is not provided
    def initialize(api_key: nil)
      @api_key = api_key || ENV.fetch('AHREFS_API_KEY', nil)
      raise ConfigurationError, 'AHREFS_API_KEY must be set' unless @api_key

      @conn = Faraday.new(url: BASE_URL) do |f|
        f.headers['Authorization'] = "Bearer #{@api_key}"
        f.headers['Accept'] = 'application/json'
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end

    # Get Domain Rating for a target domain
    #
    # @param domain [String] Target domain (e.g., 'example.com')
    # @param date [String] Date in YYYY-MM-DD format (defaults to today)
    # @return [Hash] Domain rating data including DR score and ahrefs_rank
    def get_domain_rating(domain, date: Date.today.to_s)
      request('site-explorer/domain-rating', target: domain, date: date)
    end

    # Get backlink statistics for a domain
    #
    # @param domain [String] Target domain
    # @param date [String] Date in YYYY-MM-DD format
    # @param mode [String] Analysis mode: 'subdomains', 'domain', or 'exact' (default: subdomains)
    # @return [Hash] Backlink stats including live count, referring domains
    def get_backlinks_stats(domain, date: Date.today.to_s, mode: 'subdomains')
      request('site-explorer/backlinks-stats', target: domain, date: date, mode: mode)
    end

    # Get organic keywords the domain ranks for
    #
    # @param domain [String] Target domain
    # @param country [String] Two-letter country code (default: 'us')
    # @param limit [Integer] Maximum results to return (default: 100)
    # @param mode [String] Analysis mode (default: 'subdomains')
    # @return [Hash] Organic keyword data with rankings, volume, traffic
    def get_organic_keywords(domain, country: 'us', limit: 100, mode: 'subdomains')
      request('site-explorer/organic-keywords',
              target: domain,
              country: country,
              date: Date.today.to_s,
              mode: mode,
              limit: limit,
              select: 'keyword,best_position,volume,traffic,keyword_difficulty,cpc,best_position_url')
    end

    # Get top pages by organic traffic
    #
    # @param domain [String] Target domain
    # @param country [String] Two-letter country code
    # @param limit [Integer] Maximum results
    # @param mode [String] Analysis mode
    # @return [Hash] Top pages with traffic estimates and keyword counts
    def get_top_pages(domain, country: 'us', limit: 50, mode: 'subdomains')
      request('site-explorer/top-pages',
              target: domain,
              country: country,
              date: Date.today.to_s,
              mode: mode,
              limit: limit,
              select: 'url,sum_traffic,keywords,refdomains')
    end

    # Get referring domains linking to the target
    #
    # @param domain [String] Target domain
    # @param limit [Integer] Maximum results
    # @param mode [String] Analysis mode
    # @return [Hash] Referring domain data with DR and backlink counts
    def get_referring_domains(domain, limit: 100, mode: 'subdomains')
      request('site-explorer/refdomains',
              target: domain,
              mode: mode,
              limit: limit,
              select: 'domain,domain_rating,backlinks,dofollow')
    end

    # Get organic competitors for a domain
    #
    # @param domain [String] Target domain
    # @param country [String] Two-letter country code
    # @param limit [Integer] Maximum results
    # @param mode [String] Analysis mode
    # @return [Hash] Competitor domains with common keywords and traffic
    def get_organic_competitors(domain, country: 'us', limit: 20, mode: 'subdomains')
      request('site-explorer/organic-competitors',
              target: domain,
              country: country,
              date: Date.today.to_s,
              mode: mode,
              limit: limit,
              select: 'domain,common_keywords,keywords,traffic')
    end

    # Get keyword metrics for one or more keywords
    #
    # @param keywords [String, Array<String>] Keyword(s) to analyze
    # @param country [String] Two-letter country code
    # @return [Hash] Keyword metrics including volume, difficulty, CPC
    def get_keyword_metrics(keywords, country: 'us')
      keyword_list = Array(keywords).join(',')
      request('keywords-explorer/overview',
              keywords: keyword_list,
              country: country,
              select: 'keyword,volume,keyword_difficulty,cpc,traffic_potential')
    end

    # Get related keyword ideas
    #
    # @param keywords [String, Array<String>] Seed keyword(s)
    # @param country [String] Two-letter country code
    # @param limit [Integer] Maximum results
    # @return [Hash] Related keywords with metrics
    def get_related_keywords(keywords, country: 'us', limit: 100)
      keyword_list = Array(keywords).join(',')
      request('keywords-explorer/related-terms',
              keywords: keyword_list,
              country: country,
              limit: limit,
              select: 'keyword,volume,keyword_difficulty,cpc,traffic_potential')
    end

    private

    # Make an API request
    #
    # @param endpoint [String] API endpoint path
    # @param params [Hash] Query parameters
    # @return [Hash] Parsed JSON response
    # @raise [ApiError] on API errors or network failures
    def request(endpoint, params = {})
      response = @conn.get(endpoint, params)

      unless response.success?
        AgentSeo.logger.error("Ahrefs API error: #{response.status} - #{response.body}")
        raise ApiError, "Ahrefs API request failed: #{response.status}"
      end

      JSON.parse(response.body, symbolize_names: true)
    rescue Faraday::Error => e
      AgentSeo.logger.error("Ahrefs network error: #{e.message}")
      raise ApiError, "Ahrefs network error: #{e.message}"
    end
  end
end
