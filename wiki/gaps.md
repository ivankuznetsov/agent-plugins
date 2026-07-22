# Gaps and follow-ups

- Screenote CLI PR 6 has no containing tagged release. Advance only
  `screenote_cli.minimum_release` when one is published, then refresh the
  compatibility evidence and tests.
- The protected-secret Screenote integration is opt-in for authorized release
  environments and intentionally does not run for forks or absent secrets. The
  `expired_token`, `ambiguous_project`, and `inaccessible_project` scenarios are
  offline fixtures; this queued change does not establish that a live upstream
  CLI emits those exact JSON envelopes.
- No main cross-project wiki is configured for this checkout. Project-local
  knowledge remains authoritative here.
- Automatic Screenote annotation resolution remains deferred until the
  mutation is explicitly approved in the CLI contract.
- LLM Wiki's standalone and four-host marketplace packages intentionally use
  separate version lines (`0.1.x` upstream runtime and `0.3.x` consent-gated
  marketplace package). A marketplace release must preserve the consent and
  OpenClaw adaptations while vendoring the released runtime. Marketplace
  0.3.3 through 0.3.5 vendor standalone releases 0.1.17 through 0.1.19. Local
  `llm-wiki-v0.3.3` and `llm-wiki-v0.3.4` tags exist, but no local 0.3.5 tag was
  present during this refresh. The source bump does not prove GitHub or ClawHub
  publication, scan completion, or public catalog visibility.
- Compatibility with OpenClaw releases older than `2026.7.1-beta.2` remains
  unverified. ClawHub packages therefore declare that tested version as their
  conservative plugin API floor while leaving the broader host minimum
  unspecified.
- ClawHub releases are immutable. Registry consumers should use the listed
  patch versions only after their public scans are clean; any future scan
  finding requires a new release instead of changing an existing archive.

The former Claude Code `/status` collision is closed by naming the canonical
LLM Wiki skill `wiki-status`; a transient Claude Code 2.1.179 session verified
that `/status` opens Claude's built-in screen and `/llm-wiki:wiki-status`
resolves the plugin skill.

The former Agent Reviewer host-parity gap is closed: every host now defaults to
two independent review passes, unions their findings, and applies the same
confidence gate with configurable pass/count thresholds.
