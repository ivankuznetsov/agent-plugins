# Shipped plugins

All current plugins are stable and support Claude Code, Codex, Pi, and
OpenClaw.

| Plugin | Version | Canonical workflows | Package resources |
| --- | --- | --- | --- |
| `agent-reviewer` | `0.3.0` | `agent-reviewer` | agents, references, scripts, eval |
| `agent-seo` | `1.2.0` | `seo` | agents, context, data sources, hooks, scripts |
| `agent-writing` | `0.5.1` | `writing` | agents, context |
| `llm-wiki` | `0.2.0` | `bootstrap`, `upgrade`, `research`, `wiki-plan`, `status` | assets, templates |
| `screenote` | `3.0.0` | `screenote`, `snapshot`, `feedback` | CLI launcher, references, evals |

Claude and Codex install through their root marketplaces. Pi and OpenClaw
install a copied `plugins/<name>` directory. Every copied package is complete;
no generated adapter points back to this repository.
Agent Writing treats bundled voice and anti-example context as read-only by
default. Its editor reports new anti-example candidates in project-local
reviews and persists them into the plugin only after explicit user opt-in.
