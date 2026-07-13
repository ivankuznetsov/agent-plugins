# agent-plugins

This is the toolkit I use when working with coding agents. Five plugins, vendored here so both Claude Code and Codex can install them from a single Git clone. I package it as a marketplace because that's what the agents read.

Five tools, five jobs. I picked or built each one to do a thing the others don't.

## What I use each for

**Customer-facing writing.** [`agent-writing`](plugins/agent-writing/) is what I reach for when the output is going to be read by humans who'll notice if the prose is flat. Posts, customer-facing copy, anything where voice matters. It runs three voices as rivals: a journalist who investigates and grounds, a writer who drafts, and an editor who cuts. The writer and editor never call each other — the cycle is external to both — because cooperation creates sycophancy. A single agent that drafts and then polishes its own work will praise the parts it just wrote.

**SEO content.** [`agent-seo`](plugins/agent-seo/) is my long-form pipeline for search — keyword research, drafting, humanizing AI-shaped prose, fact-checking, and optimizing against my existing site. `/seo:fact-check` ships as a first-class command because I want fact-checking inside the workflow, not bolted on after the article's already convinced me.

**UI work.** [`screenote`](plugins/screenote/) gives the agent eyes. It captures the rendered page, uploads it to [Screenote](https://screenote.ai) for human annotation, and pulls the comments back into the agent's context. I use it when the agent needs to see what it just built, instead of guessing from the DOM.

**Project documentation.** [`llm-wiki`](plugins/llm-wiki/) bootstraps and maintains an LLM-readable wiki for the project, indexed by [QMD](https://github.com/tobilu/qmd). I use it to keep what one agent learned available to the next one, across sessions and across machines. The pattern is Karpathy's — the wiki is the agent's memory, not mine.

**Code review.** [`agent-reviewer`](plugins/agent-reviewer/) clones my team's best reviewers from their PR history and runs them as a review panel. It reads a reviewer's past comments *in the context of the code they were reviewing* and extracts a persona — what they care about, what they let slide, how they sound — not a rule list. Point it at several repos and it calibrates: separating the person's standards from what one codebase happened to drag out of them. It ships a cheat-proof, model-agnostic eval harness ([`plugins/agent-reviewer/eval/`](plugins/agent-reviewer/eval/)) so you can measure a persona against the real reviewer with any model and no way to game it.

## Install

### Claude Code

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install agent-writing@aikuznetsov-marketplace
/plugin install agent-seo@aikuznetsov-marketplace
/plugin install screenote@aikuznetsov-marketplace
/plugin install llm-wiki@aikuznetsov-marketplace
/plugin install agent-reviewer@aikuznetsov-marketplace
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
plugins/agent-writing               # vendored plugin files
plugins/agent-seo                   # vendored plugin files
plugins/screenote                   # vendored plugin files
plugins/llm-wiki                    # vendored plugin files
plugins/agent-reviewer              # vendored plugin files
```

Plugins are vendored as plain directories, not submodules. Codex reads marketplace-local plugin paths from a normal clone and doesn't initialize submodules first, so vendoring is what makes a single repo work for both agents. `llm-wiki`, `screenote`, and `agent-seo` have upstream source repositories; `agent-writing` and `agent-reviewer` are born here.

## Development

When refreshing a plugin from an upstream source repo, I copy the contents into the matching `plugins/<name>` directory without the nested `.git` metadata, then update both marketplace catalogs if the plugin metadata changed.

Validate the catalogs after any edit:

```bash
jq . .claude-plugin/marketplace.json
jq . .agents/plugins/marketplace.json
```

## The through-line

One principle shows up across all four plugins: **ground claims before producing them.** `llm-wiki` doesn't invent documentation — it reads source files and records uncertainty in `wiki/gaps.md`. `agent-writing`'s journalist never writes the story they cannot ground; every citation in a brief is verified against reality before the brief is final. `agent-seo` runs fact-check as a workflow step, not a final polish. `screenote` exists because pixels are easier to lie about than to look at.

That's the style I want my agents to work in. The plugins are the implementation.

— [Ivan Kuznetsov](https://ikuznetsov.com)
