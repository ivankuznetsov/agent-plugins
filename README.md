# aikuznetsov-marketplace

Personal agent plugin marketplace for Ivan Kuznetsov projects.

This marketplace is intentionally a catalog. Plugin source remains in separate repositories, but the installable plugin files are vendored here under `plugins/<name>`. Codex reads marketplace-local plugin paths from a normal Git clone and does not initialize submodules before loading plugin details.

## Plugins

- `llm-wiki` — bootstrap and query LLM-maintained project wikis before planning or implementation.
- `screenote` — screenshot pages, upload to Screenote for human annotation, and retrieve visual feedback.
- `agent-seo` — research, write, humanize, fact-check, and optimize SEO content.

## Claude Code

Add the marketplace:

```text
/plugin marketplace add ivankuznetsov/agent-plugins
```

Install `llm-wiki`:

```text
/plugin install llm-wiki@aikuznetsov-marketplace
```

Install Screenote:

```text
/plugin install screenote@aikuznetsov-marketplace
```

Install Agent SEO:

```text
/plugin install agent-seo@aikuznetsov-marketplace
```

## Codex

Add the marketplace:

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open Codex, run `/plugins`, select `aikuznetsov-marketplace`, and install the plugin you want, including `agent-seo`.

## Repository Layout

```text
.claude-plugin/marketplace.json     # Claude Code marketplace catalog
.agents/plugins/marketplace.json    # Codex marketplace catalog
plugins/llm-wiki                    # vendored plugin files
plugins/screenote                   # vendored plugin files
plugins/agent-seo                   # vendored plugin files
```

## Development

When refreshing a plugin, copy the source repository contents into the matching `plugins/<name>` directory without the nested `.git` metadata, then update both marketplace catalogs if the plugin metadata changed.

Validate JSON:

```bash
jq . .claude-plugin/marketplace.json
jq . .agents/plugins/marketplace.json
```
