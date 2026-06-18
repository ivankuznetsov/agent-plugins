# Releasing

This marketplace hosts several independently-versioned plugins. Each plugin
ships on its own, with its own tag and GitHub release.

## Tag & release convention

- One tag per plugin release: `<plugin>-vX.Y.Z` (e.g. `llm-wiki-v0.1.9`,
  `agent-writing-v0.4.0`).
- One GitHub release per tag, targeting `main`, with notes scoped to that plugin.
- `main` is protected (1 approving review, no required CI). Land version bumps
  via a PR; admin-merge if you're working solo.

## Version markers — bump together

A plugin's version can appear in up to four places. Keep them in lockstep, or
some install channel won't see the new version:

- `.claude-plugin/marketplace.json` — the plugin's `version` entry
- `plugins/<plugin>/.claude-plugin/plugin.json`
- `plugins/<plugin>/.codex-plugin/plugin.json` (if present)
- `plugins/<plugin>/package.json` — the pi-package channel (if present)

## Steps

1. On a branch, bump every version marker above for the plugin.
2. Add a `## [X.Y.Z] - YYYY-MM-DD` section to `plugins/<plugin>/CHANGELOG.md`
   following [Keep a Changelog](https://keepachangelog.com/) (Added / Changed /
   Fixed).
3. Open a PR into `main` and merge it (admin-merge if there is no reviewer).
4. Tag and publish the release from `main`:
   ```bash
   # notes = the plugin's CHANGELOG section for this version
   awk '/^## \[X.Y.Z\]/{f=1; print; next} /^## \[/{f=0} f' \
     plugins/<plugin>/CHANGELOG.md > /tmp/notes.md
   gh release create <plugin>-vX.Y.Z --target main \
     --title "<plugin> X.Y.Z" --notes-file /tmp/notes.md
   ```
5. Users update with:
   ```bash
   claude plugin marketplace update aikuznetsov-marketplace && claude plugin update <plugin>   # Claude Code
   codex plugin marketplace upgrade aikuznetsov-marketplace                                    # Codex
   ```
   Restart the tool afterward to load the new version. The `llm-wiki` `status`
   skill can detect the available version and run the right command per tool.

## llm-wiki is vendored

`llm-wiki` is developed in its own upstream repo (`ivankuznetsov/llm-wiki`) and
**vendored** here — never edit `plugins/llm-wiki/` by hand as the source of truth.
Release order:

1. Release upstream first: bump versions + `CHANGELOG.md`, tag `vX.Y.Z`,
   `gh release create` in the `llm-wiki` repo.
2. Vendor into this repo: copy the released tree into `plugins/llm-wiki/`
   (`templates/`, `skills/`, `.claude-plugin`/`.codex-plugin` `plugin.json`,
   `package.json`, `CHANGELOG.md`) so they are byte-identical, and bump
   `marketplace.json`.
3. Tag + publish here as `llm-wiki-vX.Y.Z`.

The worktree-safe `templates/{post-commit-refresh.sh,compile-log.sh}` are also
kept byte-identical with hive, whose `Hive::WikiLog` delegates to
`compile-log.sh`.
