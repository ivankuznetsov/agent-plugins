# 2026-07-22 — LLM Wiki 0.3.2 runtime safety

- Vendored the standalone 0.1.16 queue, scheduler, and publication runtime into
  the four-host package while preserving 0.3 consent gates and OpenClaw owner
  dispatch.
- Replaced checkout-local timer proliferation with one non-persistent,
  memory-bounded timer owned by the repository primary checkout.
- Added machine-wide provider serialization, wiki-only refresh-branch
  publication, bounded source-pin transactions, and interrupted queue recovery.
- Upgrades now reconcile and stop obsolete units, leaving the timer disabled
  unless both automation consent flags are explicitly true.
