# aikuznetsov-marketplace

Personal agent plugin marketplace for Ivan Kuznetsov projects.

This marketplace is intentionally a catalog. Plugin source remains in separate repositories and is attached here through `plugins/<name>` paths, usually as git submodules.

## Plugins

- `llm-wiki` — bootstrap and query LLM-maintained project wikis before planning or implementation.
- `screenote` — screenshot pages, upload to Screenote for human annotation, and retrieve visual feedback.

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

## Codex

Add the marketplace:

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Then open Codex, run `/plugins`, select `aikuznetsov-marketplace`, and install the plugin you want.

## Repository Layout

```text
.claude-plugin/marketplace.json     # Claude Code marketplace catalog
.agents/plugins/marketplace.json    # Codex marketplace catalog
plugins/llm-wiki                    # plugin repo, expected as submodule
plugins/screenote                   # plugin repo, expected as submodule
```

## Development

After cloning this marketplace with submodules:

```bash
git submodule update --init --recursive
```

Validate JSON:

```bash
jq . .claude-plugin/marketplace.json
jq . .agents/plugins/marketplace.json
```
