---
name: wiki-status
description: Check llm-wiki install status, version freshness, update commands, and project wiki automation from Pi. Use when a Pi user asks about llm-wiki version, package updates, refresh ownership, context setup, or whether a new llm-wiki release is available.
---

# Wiki Status

This is the Pi-safe `llm-wiki` status entrypoint. It uses a prefixed skill name to avoid collisions with other Pi packages.

Before acting, read and follow the canonical status workflow at `../../../skills/status/SKILL.md`.

Pi-specific note: treat Pi as the active agent surface and report only
`/skill:wiki-upgrade` as the project upgrade command. Do not include the Claude
Code or Codex forms in the Pi status report.
