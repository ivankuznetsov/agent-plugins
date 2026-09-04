# Gaps and follow-ups

- The protected-secret Screenote integration is opt-in for authorized release
  environments and intentionally does not run for forks or absent secrets.
- No main cross-project wiki is configured for this checkout. Project-local
  knowledge remains authoritative here.
- Automatic Screenote annotation resolution remains deferred until the
  mutation is explicitly approved in the CLI contract.
- The Screenote helper now rejects multiple logical screens under one Page.
  Repairing already-published malformed snapshots remains a server/data
  operation and is outside the plugin package.
- LLM Wiki's standalone and four-host marketplace packages intentionally use
  separate version lines (`0.1.x` upstream runtime and `0.3.x` consent-gated
  marketplace package). A marketplace release must preserve the consent and
  OpenClaw adaptations while vendoring the released runtime. Marketplace
  0.3.5 vendors the released standalone 0.1.19 provider-only dispatch fix;
  public ClawHub scan and catalog visibility remain release-time evidence
  rather than source-tree facts.
- Compatibility with OpenClaw releases older than `2026.7.1-beta.2` remains
  unverified. ClawHub packages therefore declare that tested version as their
  conservative plugin API floor while leaving the broader host minimum
  unspecified.
- ClawHub releases are immutable. Agent SEO registry consumers should use
  `2.0.0` or later only after the public scan is clean; any future scan finding
  requires a new patch release instead of changing an existing archive.

The former Claude Code `/status` collision is closed by naming the canonical
LLM Wiki skill `wiki-status`; a transient Claude Code 2.1.179 session verified
that `/status` opens Claude's built-in screen and `/llm-wiki:wiki-status`
resolves the plugin skill.

The former Agent Reviewer host-parity gap is closed: every host now defaults to
two independent review passes, unions their findings, and applies the same
confidence gate with configurable pass/count thresholds.
