# Wiki Changelog

Append-only log of all wiki operations.

<!-- BEGIN GENERATED WIKI LOG FRAGMENTS -->
# 2026-07-18 — Screenote CLI error-contract coverage

Queued commit `01b4a9d` adds offline `project list` failure fixtures for an
expired token and ambiguous or inaccessible projects. The contract test now
verifies that exit-3 `expired_token` and exit-5 `ambiguous_project` /
`inaccessible_project` results stop the workflow, preserve their nested JSON
error codes and exit statuses, and return the expected bounded guidance.

No production code, approved command tuple, dependency, or public entrypoint
changed. The architecture and decision pages now record the already-shipped
fail-closed error boundary; the gaps page distinguishes fixture evidence from
live upstream CLI verification. Page coverage did not change, so the index was
left untouched.

# PR 21 review fixes

Hardened Screenote bearer routing, replaced unreachable CLI provenance with the
merged public contract, and moved deterministic workflow validation into the
shipped package. Package generation now prunes stale marker-owned artifacts and
native gates verify exact installed inventories on Claude Code, Codex, Pi, and
OpenClaw.

Reconciled the four-host LLM Wiki package with the 0.1.14 transactional refresh
and upgrade machinery from current main. OpenClaw bootstrap records a verified
workspace agent ID; headless refreshes are non-delivering and bounded; status and
project upgrade cover OpenClaw lifecycle and preserve its configured identity.

# 2026-07-17 — Four-agent plugin migration

Migrated all five shipped plugins to self-contained Claude Code, Codex, Pi,
and OpenClaw packages. Added the inventory contract, deterministic generator,
semantic lock, isolated package validation, legacy-entrypoint compatibility,
native discovery CI, and independently versioned release guidance.

Screenote now uses the external OAuth-first JSON CLI through an argv-safe
allowlist. The old transport configuration and browser-adapter fallback were
removed. Offline scenarios cover command selection, project/auth errors,
private capture recovery, cleanup, and recursive credential redaction.

Agent Reviewer's canonical flow now carries its two-pass union and confidence
gate to every host. Compatibility and migration documentation records exact CI
pins separately from unspecified upstream minimums.
<!-- END GENERATED WIKI LOG FRAGMENTS -->
