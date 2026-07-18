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
