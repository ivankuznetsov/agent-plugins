# Data Command

Fetch live performance data from configured data sources (GA4, GSC, DataForSEO, Ahrefs).

## Usage
`/seo:data [type] [arguments]`

## Types

| Type | Description | Arguments |
|------|-------------|-----------|
| `priority` | Get prioritized content task queue | `[limit]` (default: 10) |
| `opportunities` | Find content gaps and improvement areas | `[days]` (default: 30) |
| `quick-wins` | Keywords near top 10 with high potential | `[days]` (default: 30) |
| `declining` | Pages losing traffic that need attention | `[days]` (default: 30) |
| `page [url]` | Full performance analysis for a specific page | `[url]` (required) |
| `backlinks [domain]` | Backlink profile and referring domains (Ahrefs) | `[domain]` (required) |
| `authority [domain]` | Domain Rating and authority metrics (Ahrefs) | `[domain]` (required) |
| `competitors [domain]` | Organic competitors analysis (Ahrefs) | `[domain]` (required) |

## Process

### 1. Check Data Source Configuration

Before fetching data, verify which data sources are available by checking environment variables.

```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'

# Check which services are configured
available_sources = {
  ga4: !ENV['GA4_PROPERTY_ID'].to_s.empty? && File.exist?(ENV['GA4_CREDENTIALS_PATH'].to_s),
  gsc: !ENV['GSC_SITE_URL'].to_s.empty? && File.exist?(ENV['GSC_CREDENTIALS_PATH'].to_s),
  dataforseo: !ENV['DATAFORSEO_LOGIN'].to_s.empty? && !ENV['DATAFORSEO_PASSWORD'].to_s.empty?,
  ahrefs: !ENV['AHREFS_API_KEY'].to_s.empty?
}

puts "Available data sources:"
available_sources.each do |source, configured|
  status = configured ? "Configured" : "Not configured"
  puts "  #{source.upcase}: #{status}"
end
```

**If no data sources are configured:**
1. Inform the user that data sources need to be set up
2. Direct them to `data_sources/config/.env.example` for configuration
3. Explain what each source provides:
   - **GA4**: Traffic trends, pageviews, engagement metrics
   - **GSC**: Search rankings, impressions, CTR, keyword data
   - **DataForSEO**: Competitive analysis, SERP data
   - **Ahrefs**: Domain Rating, backlink analysis, organic competitors

### 2. Fetch Requested Data

Initialize the DataAggregator and call the appropriate method based on the type parameter.

#### Priority Queue
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

aggregator = AgentSeo::DataAggregator.new
limit = 10 # Adjust based on user input

results = aggregator.get_priority_queue(limit: limit)
puts JSON.pretty_generate(results)
```

#### Content Opportunities
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

aggregator = AgentSeo::DataAggregator.new
days = 30 # Adjust based on user input

results = aggregator.identify_content_opportunities(days: days)
puts JSON.pretty_generate(results)
```

#### Quick Wins
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

# GSC provides quick wins directly
begin
  gsc = AgentSeo::GoogleSearchConsole.new
  days = 30 # Adjust based on user input

  results = gsc.get_quick_wins(days: days, position_min: 11, position_max: 20, min_impressions: 50)
  puts JSON.pretty_generate(results.first(20))
rescue AgentSeo::ConfigurationError => e
  puts "Error: GSC not configured - #{e.message}"
  puts "Quick wins require Google Search Console. Set GSC_SITE_URL and GSC_CREDENTIALS_PATH."
end
```

#### Declining Content
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

aggregator = AgentSeo::DataAggregator.new
days = 30 # Adjust based on user input

opportunities = aggregator.identify_content_opportunities(days: days)
declining = opportunities[:declining_content] || []

puts JSON.pretty_generate(declining)
```

#### Page Analysis
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

aggregator = AgentSeo::DataAggregator.new
url = '/blog/example-article' # Replace with user-provided URL

results = aggregator.get_comprehensive_page_performance(url, days: 30)
puts JSON.pretty_generate(results)
```

#### Backlink Profile (Ahrefs)
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

begin
  ahrefs = AgentSeo::Ahrefs.new
  domain = 'example.com' # Replace with user-provided domain

  # Get backlink stats and referring domains
  stats = ahrefs.get_backlinks_stats(domain)
  refdomains = ahrefs.get_referring_domains(domain, limit: 20)

  puts "Backlink Stats:"
  puts JSON.pretty_generate(stats)
  puts "\nTop Referring Domains:"
  puts JSON.pretty_generate(refdomains)
rescue AgentSeo::ConfigurationError => e
  puts "Error: Ahrefs not configured - #{e.message}"
  puts "Backlink analysis requires Ahrefs. Set AHREFS_API_KEY."
end
```

#### Domain Authority (Ahrefs)
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

begin
  ahrefs = AgentSeo::Ahrefs.new
  domain = 'example.com' # Replace with user-provided domain

  dr = ahrefs.get_domain_rating(domain)
  puts JSON.pretty_generate(dr)
rescue AgentSeo::ConfigurationError => e
  puts "Error: Ahrefs not configured - #{e.message}"
end
```

#### Organic Competitors (Ahrefs)
```ruby
$LOAD_PATH.unshift(File.expand_path('data_sources/ruby/lib', Dir.pwd))
require 'agent_seo'
require 'json'

begin
  ahrefs = AgentSeo::Ahrefs.new
  domain = 'example.com' # Replace with user-provided domain

  competitors = ahrefs.get_organic_competitors(domain, country: 'us', limit: 20)
  puts JSON.pretty_generate(competitors)
rescue AgentSeo::ConfigurationError => e
  puts "Error: Ahrefs not configured - #{e.message}"
end
```

### 3. Present Results

Format the data as actionable recommendations with metrics. Use tables for lists and structured sections for detailed analysis.

## Output Formats

### Priority Queue Output
```markdown
## Content Priority Queue

| Priority | Type | Action | Reason | Est. Impact |
|----------|------|--------|--------|-------------|
| High | optimize | Optimize for "podcast analytics" | Ranking #12, 5,400 impressions. Small push to page 1. | +400 clicks/month |
| High | update | Refresh declining article | Traffic down 35% (1,200 -> 780 pageviews) | Recover +420/month |
| Medium | optimize_meta | Improve meta for /blog/hosting | 8,200 impressions, 2.1% CTR. Better meta = +300 clicks | +300 clicks/month |
| Medium | create_new | Create content for "AI transcription" | Trending +85%, 2,100 impressions | New +500/month |

### Next Steps
1. Run `/seo:analyze-existing [top-priority-url]` for detailed analysis
2. Use `/seo:optimize` or `/seo:rewrite` based on recommendation type
3. Schedule follow-up `/seo:data priority` in 2 weeks to measure impact
```

### Opportunities Output
```markdown
## Content Opportunities

### Quick Wins (Keywords positions 11-20)
| Keyword | Position | Impressions | CTR | Opportunity Score |
|---------|----------|-------------|-----|-------------------|
| podcast analytics | 12 | 5,400 | 3.2% | 87.5 |
| audio editing software | 15 | 3,200 | 2.8% | 72.3 |

### Declining Content (Traffic dropping)
| Page | Previous | Current | Change | Priority |
|------|----------|---------|--------|----------|
| /blog/podcast-equipment | 1,200 | 780 | -35% | High |

### Low CTR Pages (High impressions, low clicks)
| URL | Impressions | CTR | Missed Clicks |
|-----|-------------|-----|---------------|
| /blog/podcast-hosting | 8,200 | 2.1% | 320 |

### Trending Topics (Rising search interest)
| Query | Recent Impressions | Growth | Position |
|-------|-------------------|--------|----------|
| AI podcast editing | 2,100 | +85% | 18 |
```

### Page Analysis Output
```markdown
## Page Performance: /blog/podcast-tips

**Analysis Period:** Last 30 days
**Generated:** 2025-01-31

### Traffic Summary (GA4)
- Total Pageviews: 3,450
- Trend: Up 12% vs. previous period
- Timeline: [Shows weekly trend]

### Search Performance (GSC)
- Clicks: 890
- Impressions: 12,400
- Average CTR: 7.2%
- Average Position: 8.3

### Top Keywords
| Keyword | Clicks | Impressions | Position |
|---------|--------|-------------|----------|
| podcast tips | 245 | 3,200 | 6 |
| podcasting tips for beginners | 180 | 2,800 | 9 |
| how to start a podcast | 120 | 2,100 | 12 |

### Competitive Rankings (DataForSEO)
[Rankings data if available]

### Recommendations
1. **Quick Win**: "how to start a podcast" at position 12 - optimize for page 1
2. **CTR Opportunity**: Consider A/B testing meta description
```

## Handling Missing Configuration

When data sources are not configured, provide helpful guidance:

```markdown
## Data Source Configuration Required

The following data sources are not configured:

- **Google Search Console**: Not configured
  - Required for: keyword rankings, impressions, CTR, quick wins
  - Set: `GSC_SITE_URL` and `GSC_CREDENTIALS_PATH`

- **Google Analytics 4**: Not configured
  - Required for: traffic data, pageviews, engagement, trends
  - Set: `GA4_PROPERTY_ID` and `GA4_CREDENTIALS_PATH`

- **DataForSEO**: Not configured
  - Required for: competitive analysis, SERP features
  - Set: `DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD`

- **Ahrefs**: Not configured
  - Required for: Domain Rating, backlink analysis, organic competitors
  - Set: `AHREFS_API_KEY`

### Setup Instructions
1. Copy the example config: `cp data_sources/config/.env.example data_sources/config/.env`
2. Edit `data_sources/config/.env` with your credentials
3. See `data_sources/README.md` for detailed setup guides

### Partial Data Available
Even with partial configuration, available sources will return data.
GSC alone provides most SEO insights (rankings, quick wins, CTR).
```

## Examples

### Get Top 5 Priority Tasks
```
/seo:data priority 5
```

### Find Quick Win Keywords
```
/seo:data quick-wins
```

### Analyze Specific Page
```
/seo:data page /blog/podcast-monetization-guide
```

### Get Last 60 Days of Opportunities
```
/seo:data opportunities 60
```

## Integration with Other Commands

Use data insights to drive content actions:

1. **Quick Win Found** -> `/seo:analyze-existing [url]` -> `/seo:optimize [draft]`
2. **Declining Content** -> `/seo:analyze-existing [url]` -> `/seo:rewrite [topic]`
3. **Trending Topic** -> `/seo:research [topic]` -> `/seo:write [topic]`
4. **Low CTR Page** -> Update meta elements manually or via CMS

## Troubleshooting

### "ConfigurationError: GSC_SITE_URL must be provided"
GSC credentials not set. Check `data_sources/config/.env`.

### "No data returned"
- Verify the site URL matches exactly what's registered in GSC/GA4
- Check that service account has been granted access
- Ensure sufficient data history (some reports need 30+ days)

### "DataForSEO budget exceeded"
- Check `DATAFORSEO_DAILY_BUDGET_LIMIT` setting
- DataForSEO is optional - GSC provides core SEO data

### Partial Results
If some sources fail, others still return data. Check the `error` field in results for specifics.

## Data Freshness

- **GA4**: Typically 24-48 hour delay
- **GSC**: 2-3 day delay for search data
- **DataForSEO**: Real-time API queries
- **Ahrefs**: Updated daily, historical data available

Plan your analysis accounting for these delays.
