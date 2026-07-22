# Shipped plugins

All current plugins are stable and support Claude Code, Codex, Pi, and
OpenClaw.

| Plugin | Version | Canonical workflows | Package resources |
| --- | --- | --- | --- |
| `agent-reviewer` | `0.3.1` | `agent-reviewer` | agents, references, scripts, eval |
| `agent-seo` | `2.0.1` | `seo` | agents, context, data sources, hooks, scripts |
| `agent-writing` | `0.5.2` | `writing` | agents, context |
| `llm-wiki` | `0.3.5` | `bootstrap`, `upgrade`, `research`, `wiki-plan`, `wiki-status` | assets, consent-gated templates |
| `screenote` | `3.0.1` | `screenote`, `snapshot`, `feedback` | CLI launcher, references, evals |

The non-LLM-Wiki patch versions add the generated OpenClaw plugin API floor
without changing their canonical workflow behavior. LLM Wiki 0.3.5 also
contains the consent-gated scheduler and provider-dispatch hardening described
below.

Claude and Codex install through their root marketplaces. Pi and OpenClaw
install a copied `plugins/<name>` directory. Every copied package is complete;
no generated adapter points back to this repository.
Agent Writing treats bundled voice and anti-example context as read-only by
default. Its editor reports new anti-example candidates in project-local
reviews and persists them into the plugin only after explicit user opt-in.
Agent SEO treats its legacy `scrub` selector as a read-only formatting audit,
preserves provenance disclosures, and edits existing files only after an
explicit request for the exact path.
Version 2.0 makes the removed mutation contract explicit and documents the
1.x migration in `plugins/agent-seo/MIGRATION-2.0.md`.
LLM Wiki bootstrap creates the requested project wiki. Scheduler, managed-hook,
shared-Git, and provider-backed maintenance are a separate opt-in; 0.2.x
configs without both consent flags are automation-disabled under the 0.3
runtime. Version 0.3.5 reconciles linked checkouts to one non-persistent,
memory-bounded timer per repository, serializes providers across repositories,
publishes wiki-only output to `origin/llm-wiki/refresh`, and bounds source-ref
recovery transactions. Headless hooks reconstruct the standard user bus,
retain the scheduler marker after transient signal failure, and ignore commits
that only rewrite compiled `wiki/log.md`. The worker accepts only its configured
Codex, Claude Code, Pi, or validated OpenClaw owner; it no longer exposes an
arbitrary refresh-command environment override.
