# LLM Wiki 0.3 consent migration

LLM Wiki 0.3 makes persistent maintenance an explicit opt-in. This is a minor
pre-1.0 release because existing 0.2.x automation is disabled unless its
project config already records both consent flags.

## New config fields

`.llm-wiki/config.json` and its canonical shared-Git copy use:

```json
{
  "automation_enabled": false,
  "external_provider_access_approved": false
}
```

Missing or false values disable the post-commit worker. Manual retry does not
bypass provider consent.

## Upgrade an existing project

1. Run `wiki-upgrade` from the installed host. It updates the deterministic
   project-local LLM Wiki structure and preserves the existing config.
2. Leave automation disabled for a manual wiki, or run `wiki-bootstrap` and
   separately approve persistent maintenance. Bootstrap identifies the
   provider, scheduler commands, Claude SessionStart and Git-hook/shared-Git
   files before it may set both flags to `true`.

The optional `--check` command reports structural drift without changing the
project.

`wiki-status` reports each flag as `true`, `false`, `missing`, or `invalid`.
On OpenClaw it also reads the durable install record before checking for a new
release: `clawhub:` installs stay on ClawHub and include public visibility plus
the latest published version, marketplace installs query their recorded
marketplace, and local path installs remain explicitly development-only.

Pi and OpenClaw continue to expose `wiki-bootstrap`, `wiki-upgrade`,
`wiki-research`, `wiki-plan`, and `wiki-status`. Their inline workflows name
those collision-safe aliases explicitly. Project structure checks resolve the
actual upgrade executable at `skills/upgrade/scripts/upgrade-project.sh` under
the installed package root, never through a sibling adapter path.

The 0.3 post-commit runtime refuses to launch unless both flags are `true`.
Once enabled, it keeps the existing transactional refresh worktree, queue,
circuit-breaker, and single-owner behavior from 0.2.x.
