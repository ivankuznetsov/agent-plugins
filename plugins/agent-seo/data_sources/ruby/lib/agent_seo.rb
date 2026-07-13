# frozen_string_literal: true

require 'logger'

# AgentSeo - Ruby Data Sources for SEO Analysis
# Provides integrated access to GA4, GSC, DataForSEO, and Ahrefs data
module AgentSeo
  VERSION = '1.0.0'

  autoload :Helpers, 'agent_seo/helpers'
  autoload :GoogleAnalytics, 'agent_seo/google_analytics'
  autoload :GoogleSearchConsole, 'agent_seo/google_search_console'
  autoload :DataForSeo, 'agent_seo/data_for_seo'
  autoload :Ahrefs, 'agent_seo/ahrefs'
  autoload :DataAggregator, 'agent_seo/data_aggregator'
  autoload :KeywordAnalyzer, 'agent_seo/keyword_analyzer'
  autoload :ReadabilityScorer, 'agent_seo/readability_scorer'
  autoload :SeoQualityRater, 'agent_seo/seo_quality_rater'
  autoload :SearchIntentAnalyzer, 'agent_seo/search_intent_analyzer'
  autoload :ContentLengthComparator, 'agent_seo/content_length_comparator'
  autoload :ContentScrubber, 'agent_seo/content_scrubber'

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class << self
    attr_accessor :configuration, :logger

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end
  end

  # Default logger - logs warnings and above to stderr
  self.logger = Logger.new($stderr, level: Logger::WARN)

  class Configuration
    attr_accessor :ga4_property_id, :ga4_credentials_path,
                  :gsc_site_url, :gsc_credentials_path,
                  :dataforseo_login, :dataforseo_password,
                  :ahrefs_api_key,
                  :cache_enabled, :cache_dir

    def initialize
      @ga4_property_id = ENV.fetch('GA4_PROPERTY_ID', nil)
      @ga4_credentials_path = ENV.fetch('GA4_CREDENTIALS_PATH', nil)
      @gsc_site_url = ENV.fetch('GSC_SITE_URL', nil)
      @gsc_credentials_path = ENV.fetch('GSC_CREDENTIALS_PATH', nil)
      @dataforseo_login = ENV.fetch('DATAFORSEO_LOGIN', nil)
      @dataforseo_password = ENV.fetch('DATAFORSEO_PASSWORD', nil)
      @ahrefs_api_key = ENV.fetch('AHREFS_API_KEY', nil)
      @cache_enabled = true
      @cache_dir = 'data_sources/cache'
    end
  end
end

# Load dotenv if available
begin
  require 'dotenv'
  Dotenv.load('data_sources/config/.env')
rescue LoadError
  # dotenv not available, continue without it
end
