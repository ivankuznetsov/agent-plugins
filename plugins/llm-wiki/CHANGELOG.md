# Changelog

All notable changes to **llm-wiki** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## [0.1.12] - 2026-07-18

### Fixed

- **Ignored-wiki refresh persistence.** Projects that intentionally ignore
  `/wiki/` now seed a new local-only refresh branch from the project's existing
  wiki snapshot, then force-stage only generated wiki files. Ignored output can
  no longer be receipted and discarded after a subscription-backed refresh;
  ignored files outside `wiki/` are still rejected.
- **Repository-wide refresh circuit breaker.** Automatic provider launches stop
  after two consecutive failed batches by default, while later source commits
  continue queueing without consuming subscription runs. Set
  `LLM_WIKI_MAX_REFRESH_ATTEMPTS` to a positive integer to choose a different
  bound. After fixing the underlying problem, explicitly restore quarantined
  sources and retry queued work with:

  ```bash
  .llm-wiki/post-commit-refresh.sh --retry-failed all
  ```

  Pass a full source SHA instead of `all` to restore one quarantined record.
- **Historical owner recovery.** Project upgrades can reconstruct a missing
  `.llm-wiki/config.json` from the latest valid config in Git history when no
  live legacy script remains, while still refusing missing or conflicting
  ownership signals.

## [0.1.11] - 2026-07-18

### Added

- **Dedicated project upgrade command.** Existing projects can migrate managed
  scripts, the post-commit hook block, and the fragment-based changelog layout
  with `/llm-wiki:upgrade`, `$llm-wiki:upgrade`, or `/skill:wiki-upgrade`,
  without rerunning broad wiki generation or changing the headless owner.
- **Deterministic migration checks.** The bundled upgrader supports a read-only
  `--check` mode, preserves unrelated dirty work and unmarked hook logic, and is
  byte-for-byte idempotent after a successful migration.
- **Legacy owner recovery.** Projects that predate `.llm-wiki/config.json` can
  be upgraded automatically when their managed scripts identify exactly one
  headless owner. Ambiguous or missing ownership stops before any write.

### Changed

- **One owner-aware refresh template.** Every project now receives the same
  transactional post-commit script. It reads the preserved `headless_agent` at
  runtime and dispatches to exactly one of Codex, Claude Code, or Pi from the
  managed refresh worktree.

### Fixed

- **Subscription-safe execution bounds.** Provider overrides, Codex, Claude
  Code, Pi, and QMD all require `timeout` or `gtimeout`. If neither is
  available, the worker starts no provider, retains the queue, and cleans up its
  lock and disposable worktree.
- **Lossless migration refusal.** Reversed, nested, duplicated, or unmatched
  changelog and hook markers now stop the upgrade before any project write;
  marker-free legacy logs retain both headed entries and unheaded prose.
- **Checkout-local owner selection.** Runtime dispatch reads the committing
  checkout's config, so ignored or otherwise untracked config still selects the
  intended owner without leaking into the managed refresh branch.

### Upgrade existing projects

Updating the `llm-wiki` plugin or Pi package does **not** rewrite files already
copied into project checkouts. After updating and restarting the agent, run the
appropriate upgrade command once inside every existing project:

```text
Claude Code: /llm-wiki:upgrade
Codex:       $llm-wiki:upgrade
Pi:          /skill:wiki-upgrade
```

The command changes only managed llm-wiki structure. It preserves the selected
headless owner, unrelated hook logic, existing wiki content, and other dirty
checkout changes; it never runs an LLM or commits the migration.

Post-commit refreshes require `timeout` (normally present on Linux) or
`gtimeout` (GNU coreutils on macOS). Without one, refresh work remains queued and
no subscription-backed provider is started.

## [0.1.10] - 2026-07-18

Transactional wiki maintenance that stays completely out of your working
checkouts. Post-commit refreshes now collect relevant commits in Git-managed
state, update a dedicated local refresh branch, and leave both the primary
checkout and feature worktrees exactly as they were.

### Added

- **Dedicated refresh branch and worktree.** Wiki maintenance runs on the local
  `llm-wiki/refresh` branch in a disposable managed worktree. The branch is
  intentionally never pushed automatically, so its commits can be inspected,
  merged, or proposed on the operator's schedule.
- **Replay-safe source receipts.** Successful batches record
  `refs/llm-wiki/receipts/<source-sha>` and matching `LLM-Wiki-Source` commit
  trailers. A crash after committing but before queue cleanup can therefore be
  replayed without invoking the agent or creating a duplicate refresh commit.
- **End-to-end transaction coverage.** The new shell integration test exercises
  dirty-checkout preservation, linked-worktree commits, refresh-branch output,
  receipt replay, malformed-lock recovery, no-op refreshes, and bounded QMD
  maintenance. GitHub Actions now runs it for template, test, and release
  metadata changes.

### Changed

- **Queued, coalesced refreshes.** Relevant post-commit events are written under
  the repository's shared Git directory before lock acquisition. One worker
  snapshots and documents the pending sources together; commits arriving while
  it runs remain queued for the next batch.
- **Read-only user checkouts.** The triggering checkout and the primary checkout
  are inputs only. Agent edits, staging, commits, logs, lock state, queue files,
  and fallback QMD cache data all live in the managed refresh worktree or shared
  Git directory.
- **Broader relevance detection.** Common application, library, test, template,
  and configuration trees now trigger focused wiki maintenance alongside
  schema, API, dependency, plan, note, and documentation changes.

### Fixed

- **Dirty checkout and branch mutations.** Post-commit refreshes no longer write
  generated wiki pages into a developer's primary checkout, stage their pending
  edits, or advance its branch while other work is in progress.
- **Race-safe lock recovery.** The shared worker lock is now a Git ref updated
  with compare-and-swap semantics. Dead, PID-reused, and malformed owners can be
  reclaimed without allowing two workers to win or an old worker to release a
  successor's lock.
- **Clean, retryable failures.** Agent, validation, compilation, staging, commit,
  and receipt failures retain their queue entries and discard the disposable
  worktree. Any tracked or untracked edit outside `wiki/` is rejected before a
  refresh can be committed.
- **ShellCheck-clean cleanup handling.** The EXIT-trap cleanup function is
  explicitly marked as indirectly invoked, keeping the transactional script
  clean under ShellCheck without weakening cleanup behavior.

## [0.1.9] - 2026-06-18

Worktree-safe wiki maintenance and a single shared changelog compiler. The
post-commit refresh is now safe to run from any git worktree, and the changelog
format lives in one shell script shared verbatim by the plugin and by hive's
`Hive::WikiLog`.

### Added

- **Worktree-safe post-commit refresh.** The wiki is treated as global state that
  lives on the **main checkout**. A commit in a linked worktree reads the
  just-committed code there, but reads/writes/commits the wiki only on the main
  checkout — so the linked worktree's own `wiki/` is never touched and its
  `git status` stays clean. (`templates/post-commit-refresh.sh`)
- **Single shared log compiler.** `templates/compile-log.sh` compiles
  `wiki/log.md` from append-only `wiki/log.d/*.md` fragments — the one source of
  truth for the changelog format, shared verbatim with hive (`Hive::WikiLog`
  delegates to it, so Ruby and shell callers run identical logic).
- **Real, bundled script templates.** `templates/post-commit-refresh.sh` and
  `templates/compile-log.sh` are now installed verbatim on bootstrap instead of
  being re-derived from prose, so every project — and every checkout of the same
  project — runs identical, tested logic.

### Changed

- **Fragment-based changelog model.** New work is recorded as
  `wiki/log.d/<timestamp>-<slug>.md` fragments and `wiki/log.md` is recompiled
  from them rather than hand-edited. Fragments are append-only and conflict-free
  across concurrent worktrees.
- **Bootstrap contract.** `skills/bootstrap/SKILL.md` now documents the
  worktree-safe invariants (main-checkout wiki home, shared-git-dir lock,
  scoped + guarded commit, never push) and instructs copying both scripts
  verbatim rather than generating them from prose.

### Fixed

- **Serialized, non-racing refreshes.** All refreshes serialize on a single lock
  in the shared git dir, so N concurrent worktree commits never race the main
  checkout's index. A stale lock — owner process gone, or older than its TTL
  (`LLM_WIKI_LOCK_TTL`, default 3600s) — is reclaimed instead of wedging
  refreshes forever.
- **Recursion-safe, push-safe commits.** The wiki commit is scoped to `wiki/`,
  runs with the hook disabled (`HIVE_SKIP_LLM_WIKI_POST_COMMIT=1` plus
  `core.hooksPath=/dev/null`) so it cannot re-trigger itself, and is **never
  pushed** so an in-progress branch is never diverged from its remote.
- **Quoted refresh-command override.** `LLM_WIKI_REFRESH_CMD` is quoted so a
  command path containing spaces works.
- **Locale-stable log stripping.** Fragment trimming is pinned to `LC_ALL=C` so
  it matches Ruby `String#strip` across locales and awk implementations.
- **Loud failure logging** around `git add` / `commit` / compile, so wiki edits
  are never silently stranded as uncommitted residue.

## [0.1.7] - 2026-06-01

- Pi support and shared wiki context across agents (`claude`, `codex`, `pi`).
- Simpler wiki command names; plugin update-status skill.
