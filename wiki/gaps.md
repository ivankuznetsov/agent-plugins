# Gaps and follow-ups

- Screenote CLI PR 6 has no containing tagged release. Advance only
  `screenote_cli.minimum_release` when one is published, then refresh the
  compatibility evidence and tests.
- The protected-secret Screenote integration is opt-in for authorized release
  environments and intentionally does not run for forks or absent secrets.
- No main cross-project wiki is configured for this checkout. Project-local
  knowledge remains authoritative here.
- Automatic Screenote annotation resolution remains deferred until the
  mutation is explicitly approved in the CLI contract.
- LLM Wiki 0.3.0 upstream release/tag publication remains a release-management
  step. The ClawHub replacement is not verified until the exact merged source
  is published and publicly visible.
- ClawHub's package inspector reports a P2 compatibility-metadata warning for
  these bundle plugins because OpenClaw's formal minimum supported version is
  still unspecified. The contract records the tested host version without
  inventing a minimum.
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
