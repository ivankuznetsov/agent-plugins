---
name: wiki-bootstrap
description: Bootstrap an LLM-maintained wiki for the current project from Pi. Use when a Pi user asks to create, initialize, refresh, or configure a project wiki, LLM wiki, QMD wiki, or codebase knowledge base.
---

# Wiki Bootstrap

This is the Pi-safe `llm-wiki` bootstrap entrypoint. It uses a prefixed skill name to avoid collisions with other Pi packages.

Before acting, read and follow the canonical bootstrap workflow at `../../../skills/bootstrap/SKILL.md`.

Pi-specific notes:

- Pi receives project wiki context through `AGENTS.md`.
- Do not create `.pi/SYSTEM.md` or `.pi/APPEND_SYSTEM.md` during bootstrap unless the user explicitly asks for Pi-specific system prompt customization.
- If Pi is the first tool to bootstrap the project and no legacy headless owner exists, set `.llm-wiki/config.json` `headless_agent` to `pi`.
- Pi headless automation uses `pi -p --no-session --tools read,bash,edit,write,grep,find,ls`.
