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
