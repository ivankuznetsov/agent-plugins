# Dependencies

There is no root application build or root package manager. Contract,
generation, semantic parity, and offline behavior tests use Python 3 and its
standard library.

The exact native discovery pins are Claude Code `2.1.179`, Codex CLI
`0.144.3`, Pi `0.80.10`, and OpenClaw `2026.7.1-beta.2`. These are tested
versions, not claimed formal minimums.

Screenote depends on the external `screenote` executable. The current
OAuth-first JSON baseline is the reachable merged PR 6 at
`c28ac8b3b1b720ef60275e5f59db3a96f8cfa98b`. No containing CLI release is
tagged, so `plugin-surfaces.json#screenote_cli.minimum_release` remains null.
The plugin detects the executable but never installs it. Its generated
allowlist and shipped workflow contract share that pinned public provenance.

Workflow-specific optional dependencies remain local to their plugins:

- Agent Reviewer uses authenticated `gh` and `jq`; its eval isolation can use
  `unshare` and `bwrap`.
- Agent SEO's local analysis utilities use Ruby and Bundler; prompt workflows
  do not require Ruby. Version 2.0 removes `dotenv` and does not auto-load a
  repository `.env`; live provider configuration comes from explicit process
  environment values, and its setup guidance keeps credential files outside
  the repository.
- LLM Wiki prefers QMD and falls back to `rg`. Automated refresh also requires
  `git` plus `timeout` or `gtimeout`, but the final 0.3 source adds no
  `bubblewrap` or `sandbox-exec` runtime dependency.
- Screenote capture uses each host's native browser automation.
