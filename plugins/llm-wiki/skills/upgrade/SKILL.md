---
name: upgrade
description: Upgrade an existing project's managed llm-wiki structure without rerunning broad wiki bootstrap. Use when a user asks to migrate, update, or upgrade project-local .llm-wiki scripts, hooks, or changelog structure after installing a newer llm-wiki release.
---

# Upgrade LLM Wiki Project Structure

Upgrade the current project's managed llm-wiki files to the templates bundled
with this installed release. This is a narrow, deterministic migration: do not
regenerate wiki pages, switch the headless owner, run a refresh agent, update
QMD, or reinstall the scheduler.

## Preconditions

- The current directory must be inside a Git repository already bootstrapped
  with `.llm-wiki/` and `wiki/`.
- When `.llm-wiki/config.json` exists, read it and report the configured
  `headless_agent`. Preserve the file byte-for-byte.
- When the config is missing, the script infers the owner only when legacy
  managed scripts and the latest added or modified config in Git history
  identify exactly one of Codex, Claude Code, or Pi. It creates the config with
  that owner; zero or multiple candidates stop the migration before any project
  file is changed.

## Run the Upgrade

Resolve `scripts/upgrade-project.sh` relative to this SKILL.md and run:

```bash
skills/upgrade/scripts/upgrade-project.sh --project "$(git rev-parse --show-toplevel)"
```

Use the resolved installed path, not the example's repository-relative path.
When the user asks only whether an upgrade is needed, run `--check` instead.
Exit status `10` means an upgrade is available; it is an expected check result,
not a migration failure.

The script upgrades only managed structure:

- `.llm-wiki/post-commit-refresh.sh`
- `.llm-wiki/compile-log.sh`
- a missing `.llm-wiki/config.json` when live or historical evidence identifies
  one unambiguous legacy owner
- `wiki/log.d/` and the compiled `wiki/log.md` layout
- the marked `LLM WIKI POST-COMMIT` block in the active Git hook path

The post-commit template is identical in every project. At runtime it reads the
preserved `headless_agent` and dispatches to exactly one of Codex, Claude Code,
or Pi from the managed refresh worktree.

## Safety Contract

- Preserve unrelated tracked and untracked project changes.
- Overwrite only the two llm-wiki-managed scripts listed above.
- Replace or deduplicate only the marked post-commit hook block; preserve all
  unmarked hook logic and refuse unmatched markers.
- Preserve all hand-written legacy changelog prose while introducing the
  generated fragment block. Refuse malformed generated-log markers.
- Never commit, stage, push, invoke an LLM, or change branches.
- A second upgrade must be byte-for-byte idempotent.

## Report

Report:

- Whether the project was upgraded or already current.
- Configured headless owner.
- Managed files changed.
- Whether unrelated dirty work remained unchanged.
- Any validation failure that prevented migration.
