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
