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
