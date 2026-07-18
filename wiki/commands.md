# Public entrypoints

Claude Code retains its established slash commands:

- Agent Reviewer: `/reviewer:extract`, `/reviewer:review`, and
  `/reviewer:update`, including `--passes` and `--min-confidence` review options.
- Agent SEO: `/seo:analyze-existing`, `/seo:data`, `/seo:fact-check`,
  `/seo:humanize`, `/seo:optimize`, `/seo:performance-review`, `/seo:research`,
  `/seo:rewrite`, `/seo:scrub`, and `/seo:write`.
- Agent Writing: `/write:editor-ru`, `/write:editor`, `/write:full`,
  `/write:journalist`, `/write:writer-ivan`, `/write:writer-ru`, and
  `/write:writer`.
- LLM Wiki: `bootstrap`, `upgrade`, `research`, `wiki-plan`, and `status` in its
  plugin namespace.
- Screenote: `/screenote [viewport] <URL-or-page>`,
  `/snapshot [viewport] <base-URL>`, and `/feedback [viewport] [filter]`.

Codex uses the installed plugin skill names. Pi and OpenClaw use
`agent-reviewer`, `agent-seo`, `agent-writing`, `screenote`, `snapshot`, and
`feedback`. LLM Wiki retains its collision-safe Pi names on both generated
hosts: `wiki-bootstrap`, `wiki-upgrade`, `wiki-research`, `wiki-plan`, and
`wiki-status`.

Generated Claude command wrappers choose one canonical mode and forward
arguments without reparsing them. `tests/fixtures/entrypoints.json` is the
compatibility authority for legacy argument grammar.
