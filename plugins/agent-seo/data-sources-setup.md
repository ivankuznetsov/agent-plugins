# Data Sources Setup Guide

Agent SEO can read Google Analytics 4, Google Search Console, DataForSEO, and
Ahrefs only when the user explicitly selects the `data` or
`performance-review` workflow. All integrations are optional; prompt-driven
research, writing, revision, fact-checking, and optimization work without them.

## Security baseline

- Prefer workload identity, a secret manager, or an OS keychain over downloaded
  long-lived keys.
- Grant read-only access and the narrowest property/site scope available.
- Never store credentials, service-account JSON, or a populated `.env` inside
  the repository.
- If a credential file is unavoidable, keep it in a user-owned configuration
  directory outside the project and set mode `0600` before use.
- Export secrets only for the process that needs them, rotate them regularly,
  and remove access when the integration is no longer used.

Example private directory:

```bash
install -d -m 700 "$HOME/.config/agent-seo"
install -m 600 /path/to/downloaded-key.json "$HOME/.config/agent-seo/google.json"
```

Do not copy literal secret values into shell history. Configure them through
your secret manager or a protected shell/session environment.

## Google Analytics 4

1. Enable the Google Analytics Data API in a Google Cloud project.
2. Prefer workload identity. If that is unavailable, create a dedicated
   service account and grant it Viewer access to the required GA4 property.
3. Set the property ID and the absolute path to the protected credential file:

```bash
export GA4_PROPERTY_ID="your-property-id"
export GA4_CREDENTIALS_PATH="$HOME/.config/agent-seo/google.json"
```

## Google Search Console

1. Enable the Google Search Console API.
2. Add the dedicated service account as a Restricted user for view-only report
   access to the intended site; never grant Owner. See Google's
   [permission reference](https://support.google.com/webmasters/answer/7687615).
3. Set the exact property URL and protected credential path:

```bash
export GSC_SITE_URL="https://example.com/"
export GSC_CREDENTIALS_PATH="$HOME/.config/agent-seo/google.json"
```

## DataForSEO

Store the API login and password in a secret manager or protected session
environment:

```bash
export DATAFORSEO_LOGIN="your-login"
export DATAFORSEO_PASSWORD="your-password"
```

DataForSEO is paid and may charge per request. Check the current provider
pricing, set account budget limits, and use the smallest query scope needed.

## Ahrefs

Use a protected session variable for the API key:

```bash
export AHREFS_API_KEY="your-api-key"
```

Ahrefs requires an account with API access and may impose plan or usage limits.

## Before the first query

The agent must state which configured providers it will query, the site or
property scope, the time range, and the fields it expects to return. If the
user's request did not already authorize that exact access, the agent pauses
for confirmation. Credentials and unrelated analytics records must never be
included in generated artifacts.

## Test configuration

Run an explicit, minimal data request and verify that only the intended source
and property are accessed. If a source is absent or misconfigured, Agent SEO
returns partial results with setup guidance rather than attempting unrelated
credentials or failing the whole workflow.
