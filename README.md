# agent-plugins

This is the toolkit [Ivan Kuznetsov](https://ikuznetsov.com) actually uses when working with coding agents. Four plugins, vendored here so both Claude Code and Codex can install them from a single Git clone. It happens to be packaged as a marketplace because that's what the agents read — but the shape of the repo is a working environment, not a catalog.

The four plugins compose into a loop. They were not picked off a shelf; they were built or chosen because each one fills a hole the others leave open.

## The loop

**Research before you plan.** [`llm-wiki`](plugins/llm-wiki/) bootstraps an LLM-maintained wiki for the project and indexes it with [QMD](https://github.com/tobilu/qmd) so the next agent that touches the codebase reads what the last one learned. The pattern is Karpathy's — the wiki is the agent's memory across sessions, not yours.

**See what the agent built.** [`screenote`](plugins/screenote/) gives the agent eyes. It captures the rendered page, uploads it to [Screenote](https://screenote.ai) for human annotation, and pulls the comments back into the agent's context. Visual ground truth for UI work, instead of guessing from the DOM.

**Turn research into long-form.** [`agent-seo`](plugins/agent-seo/) is the SEO pipeline — research a topic, draft the article, humanize the prose, fact-check the claims, and optimize against the existing site. It ships `/seo:fact-check` as a first-class command because the worldview running through this whole repo doesn't tolerate ungrounded prose.

**Hold the writing accountable.** [`agent-writing`](plugins/agent-writing/) runs three voices as rivals: a journalist who investigates and grounds, a writer who drafts, and an editor who cuts. The writer and editor never call each other — the cycle is external to both — because cooperation creates sycophancy. A single agent that drafts and then polishes its own work will praise the parts it just wrote.

The connections are real, not aspirational. `agent-writing`'s journalist explicitly looks for `qmd` and uses `llm-wiki`'s index when it's available. `llm-wiki:wiki-plan` delegates to Compound Engineering when that plugin is present. The plugins know about each other.

## Install

### Claude Code

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install llm-wiki@aikuznetsov-marketplace
/plugin install screenote@aikuznetsov-marketplace
/plugin install agent-seo@aikuznetsov-marketplace
/plugin install agent-writing@aikuznetsov-marketplace
```

### Codex

```bash
codex plugin marketplace add ivankuznetsov/agent-plugins
```

Open Codex, run `/plugins`, select `aikuznetsov-marketplace`, and install the plugins you want.

## Repository layout

```text
.claude-plugin/marketplace.json     # Claude Code marketplace catalog
.agents/plugins/marketplace.json    # Codex marketplace catalog
plugins/llm-wiki                    # vendored plugin files
plugins/screenote                   # vendored plugin files
plugins/agent-seo                   # vendored plugin files
plugins/agent-writing               # vendored plugin files
```

Plugins are vendored as plain directories, not submodules. Codex reads marketplace-local plugin paths from a normal clone and doesn't initialize submodules before loading plugin details, so vendoring is what makes a single repo work for both agents. Some plugins (`llm-wiki`, `screenote`, `agent-seo`) have upstream source repositories; `agent-writing` is born here.

## Development

When refreshing a plugin from an upstream source repo, copy the contents into the matching `plugins/<name>` directory without the nested `.git` metadata, then update both marketplace catalogs if the plugin metadata changed.

Validate the catalogs after any edit:

```bash
jq . .claude-plugin/marketplace.json
jq . .agents/plugins/marketplace.json
```

## The worldview

One principle runs through all four plugins: **ground claims before you produce them.** `llm-wiki` does not invent documentation — it reads source files and records uncertainty in `wiki/gaps.md`. `agent-writing`'s journalist never writes the story they cannot ground; every citation in a brief is verified against reality before the brief is final. `agent-seo` runs fact-check as a workflow step, not a final polish. `screenote` exists because pixels are easier to lie about than to look at.

That is what makes these four a kit, and not just four installs.
