# Shipped plugins

All current plugins are stable and support Claude Code, Codex, Pi, and
OpenClaw.

| Plugin | Version | Canonical workflows | Package resources |
| --- | --- | --- | --- |
| `agent-reviewer` | `0.3.0` | `agent-reviewer` | agents, references, scripts, eval |
| `agent-seo` | `1.2.0` | `seo` | agents, context, data sources, hooks, scripts |
| `agent-writing` | `0.5.0` | `writing` | agents, context |
| `llm-wiki` | `0.2.0` | `bootstrap`, `research`, `wiki-plan`, `status` | assets, templates |
| `screenote` | `3.0.0` | `screenote`, `snapshot`, `feedback` | CLI launcher, references, evals |

Claude and Codex install through their root marketplaces. Pi and OpenClaw
install a copied `plugins/<name>` directory. Every copied package is complete;
no generated adapter points back to this repository.
