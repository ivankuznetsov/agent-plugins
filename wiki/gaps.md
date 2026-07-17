# Gaps and follow-ups

- Screenote CLI PR 37 has no containing tagged release. Advance only
  `screenote_cli.minimum_release` when one is published, then refresh the
  compatibility evidence and tests.
- The protected-secret Screenote integration is opt-in for authorized release
  environments and intentionally does not run for forks or absent secrets.
- No main cross-project wiki is configured for this checkout. Project-local
  knowledge remains authoritative here.
- Automatic Screenote annotation resolution remains deferred until the
  mutation is explicitly approved in the CLI contract.

The former Agent Reviewer host-parity gap is closed: every host now defaults to
two independent review passes, unions their findings, and applies the same
confidence gate with configurable pass/count thresholds.
