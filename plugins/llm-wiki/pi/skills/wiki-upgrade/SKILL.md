---
name: wiki-upgrade
description: Upgrade an existing project's managed llm-wiki structure from Pi without rerunning broad bootstrap.
---

# Wiki Upgrade

This is the Pi-safe `llm-wiki` project-upgrade entrypoint. It uses a prefixed
skill name to avoid collisions with other Pi packages.

Before acting, read and follow the canonical upgrade workflow at
`../../../skills/upgrade/SKILL.md`.

Pi-specific note: preserve the configured `headless_agent`; running the upgrade
from Pi does not transfer scheduled or post-commit maintenance ownership to Pi.
