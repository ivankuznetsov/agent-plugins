---
title: Restrict LLM Wiki refreshes to configured providers
date: 2026-07-22T21:17:00Z
tags: [llm-wiki, security, providers, clawhub]
---

Marketplace LLM Wiki 0.3.5 vendors standalone runtime 0.1.19 and removes the
undocumented `LLM_WIKI_REFRESH_CMD` arbitrary executable override. The worker
retains its separate automation and provider-access consent gate, but once
enabled it can dispatch only to the configured Codex, Claude Code, Pi, or
validated OpenClaw owner through fixed command shapes and existing timeouts.

This closes the one unexpected issue from ClawHub's delayed semantic scan of
0.3.4. Findings about durable hooks, timers, wiki writes, and refresh-branch
publication describe the package's disclosed opt-in purpose and remain subject
to the existing consent, path, lock, memory, and wiki-only publication guards.
