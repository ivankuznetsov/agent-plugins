# Changelog

All notable changes to **llm-wiki** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project adheres to
[Semantic Versioning](https://semver.org/).

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
