# Wiki Changelog

Append-only log of all wiki operations.

<!-- BEGIN GENERATED WIKI LOG FRAGMENTS -->
---
title: Coalesce LLM Wiki 0.3.3 through 0.3.5 runtime hardening
date: 2026-07-22T22:08:20Z
tags: [llm-wiki, systemd, scheduler, providers, security]
---

Coalesced queued branch-tip commits `a7bc290`, `a93917b`, and `3aa72cc` into
the final marketplace 0.3.5 source state. Version 0.3.3 restores the standard
user-systemd bus environment for headless hooks and upgrades, retains the
scheduler marker when a best-effort signal fails, falls back through the
existing machine-wide serialization path, and excludes commits that only update
compiled `wiki/log.md` before queueing or provider launch.

Version 0.3.4 changes the managed service's outer start limit from 45 minutes
to four hours so an allowed three-batch drain can finish. The 4 GiB memory
ceiling, no-swap policy, machine-wide provider lock, and smaller agent and QMD
phase limits remain in force. Version 0.3.5 removes the undocumented
`LLM_WIKI_REFRESH_CMD` executable override; after both consent gates pass, the
worker can dispatch only to the configured Codex, Claude Code, Pi, or validated
OpenClaw owner through fixed command shapes.

The batch changes no public skill inventory, command grammar, data model, or
runtime dependency. Page coverage is unchanged, so `wiki/index.md` remains
untouched; the compiled `wiki/log.md` was not edited. Local 0.3.3 and 0.3.4 tags
exist, while 0.3.5 publication, scan completion, and public catalog visibility
remain release-time evidence recorded in `wiki/gaps.md`.

---
title: Restrict LLM Wiki refreshes to configured providers
date: 2026-07-22T21:17:00Z
tags: [llm-wiki, security, providers, clawhub]
---

Marketplace LLM Wiki 0.3.5 vendors standalone runtime 0.1.19 and removes the
undocumented `LLM_WIKI_REFRESH_CMD` arbitrary executable override. The worker
retains its separate automation and provider-access consent gate, but once
enabled it can dispatch only to the configured Codex, Claude Code, Pi, or
validated OpenClaw owner through fixed command shapes and existing timeouts.

This closes the one unexpected issue from ClawHub's delayed semantic scan of
0.3.4. Findings about durable hooks, timers, wiki writes, and refresh-branch
publication describe the package's disclosed opt-in purpose and remain subject
to the existing consent, path, lock, memory, and wiki-only publication guards.

---
title: Keep LLM Wiki bounded scheduling reachable from headless hooks
date: 2026-07-22T20:38:00Z
tags: [llm-wiki, systemd, scheduler, queue, release]
---

Prepared LLM Wiki marketplace 0.3.3 from the released standalone 0.1.17
runtime while retaining the four-host consent gate and OpenClaw owner
dispatch. Commit hooks and scheduler upgrades now reconstruct missing
user-systemd bus variables from the standard per-user socket. A failed signal
keeps the installed scheduler marker and uses the existing serialized fallback
for the current queue instead of disabling later bounded dispatch.

Commits changing only compiled `wiki/log.md` now exit before queue creation,
source pinning, or provider launch. Source fragments and other project changes
remain eligible. Regression coverage exercises the real shell templates for
compiled-log no-op behavior, bus recovery, marker retention, and fallback.

# 2026-07-22 — ClawHub safety and compatibility batch

Coalesced five queued source records into their three final outcomes. Agent SEO
2.0 makes the legacy scrubber and Ruby CLI read-only, removes the cleaned-output
contract and repo-local dotenv loading, preserves provenance, defaults editorial
work to new artifacts, gates existing-path edits and live data access on explicit
scope, and excludes development-only material from the ClawHub bundle.

LLM Wiki 0.3 separates requested wiki creation from persistent automation,
requires both consent flags before automatic dispatch, inlines the canonical
Pi/OpenClaw workflows, and uses collision-safe `wiki-*` names. The final
`dc69df8` source supersedes the provider-sandbox variants at `ce506cf` and
`0bbc7f0`: provider execution remains in the established bounded direct
transaction and adds no `bubblewrap` or `sandbox-exec` runtime dependency.

The OpenClaw compatibility patch declares
`openclaw.compat.pluginApi >=2026.7.1-beta.2` from the exact tested host pin and
bumps all five packages to their current patch versions. The commits do not
prove upstream release publication, ClawHub scan completion, public visibility,
or compatibility with older OpenClaw versions; those remain gaps. Page coverage
did not change, so `wiki/index.md` was left untouched, and the compiled
`wiki/log.md` was not edited.

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

# OpenClaw plugin API compatibility metadata

Generated package metadata now declares `openclaw.compat.pluginApi` for every
plugin, using the OpenClaw version recorded by the four-host contract as the
conservative API floor. Patch releases update all five immutable ClawHub
packages, and regression coverage prevents the compatibility field from being
omitted again.

# LLM Wiki preserves Claude Code's built-in status command

Renamed the canonical LLM Wiki status skill to `wiki-status`. Claude Code had
accepted the unqualified plugin skill name `status`, causing plain `/status` to
start `/llm-wiki:status` instead of opening Claude's built-in status screen.
The collision-safe name is shared across Claude Code, Codex, Pi, and OpenClaw.

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

# LLM Wiki separates project writes from persistent automation

LLM Wiki 0.3.0 keeps bootstrap focused on generating the requested project wiki.
Schedulers, managed Git hooks, shared-Git runtimes, and provider-backed
refreshes require a separate approval. Existing 0.2.x configs without both
consent flags remain manual.

Generated Pi/OpenClaw skills inline the canonical behavior and name their
collision-safe `wiki-*` siblings explicitly. `wiki-status` reports both consent
flags and keeps OpenClaw update checks on the recorded ClawHub, marketplace, or
local-development source.

# Agent Writing requires opt-in before persisting bundled context

Agent Writing 0.5.1 treats its bundled `context/` directory as read-only by
default. Editors put new anti-example candidates into the project-local review
and modify the bundled anti-example collection only after explicit user opt-in.

The change closes the persistence ambiguity reported by ClawHub's scan of the
initial 0.5.0 bundle without removing the reusable anti-example workflow.

# Agent SEO narrows mutation and provenance behavior

Agent SEO 2.0.0 replaces the legacy content transformation behind `scrub` with
a read-only formatting audit. Editorial workflows preserve authorship and
provenance disclosures, create new artifacts by default, and require an
explicit request before editing an existing path.

Live analytics access now starts only from an explicit data workflow with a
declared source and scope. Credential guidance uses protected storage outside
the repository, and the ClawHub bundle excludes development-only todos/tests,
generated output, and validator reports.

The release is versioned 2.0.0 because the old scrub CLI and Ruby write
contracts are intentionally removed. The replacement audit covers Unicode
category `Cf`, reports one-based locations, rejects unsafe file inputs, and has
a dedicated migration guide and process-level regression tests.

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
