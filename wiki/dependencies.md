# Dependencies

There is no root application build or root package manager. Contract,
generation, semantic parity, and offline behavior tests use Python 3 and its
standard library.

The exact native discovery pins are Claude Code `2.1.179`, Codex CLI
`0.144.3`, Pi `0.80.10`, and OpenClaw `2026.7.1-beta.2`. These are tested
versions, not claimed formal minimums.

Screenote depends on the external `screenote` executable. The current JSON
baseline is Screenote CLI v0.4.1, merged by PR 18 at
`cce90049d1335413bd903d7da4882d20615fa5d3`. The plugin records `0.4.1` as its
minimum release because snapshot publication now also requires one stable Page
identity per logical screen. It detects the executable but never installs it.
Its generated allowlist and shipped workflow contract share that pinned public
provenance.

Workflow-specific optional dependencies remain local to their plugins:

- Agent Reviewer uses authenticated `gh` and `jq`; its eval isolation can use
  `unshare` and `bwrap`.
- Agent SEO's local analysis utilities use Ruby and Bundler; prompt workflows
  do not require Ruby.
- LLM Wiki prefers QMD and falls back to `rg`.
- Screenote capture uses each host's native browser automation.
