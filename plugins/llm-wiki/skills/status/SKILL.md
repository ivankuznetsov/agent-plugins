---
name: status
description: Check whether llm-wiki is current, detect newer marketplace or package versions, and suggest or run the right update command for Claude Code, Codex, Pi, or OpenClaw. Use when the user asks about llm-wiki version, plugin/package updates, marketplace refresh, upgrade instructions, project context setup, or whether a new llm-wiki release is available.
---

# LLM Wiki Status

Check whether `llm-wiki` is current and report the exact update command for the current agent environment.

Also inspect project-local wiki configuration when available:

- `.llm-wiki/config.json`
- `AGENTS.md`
- `CLAUDE.md`
- `.pi/settings.json`
- `.claude/settings.json`
- `.llm-wiki/refresh-wiki.sh`
- `.llm-wiki/post-commit-refresh.sh`
- `$(git rev-parse --git-common-dir)/llm-wiki/post-commit-refresh.sh`
- `$(git rev-parse --git-common-dir)/llm-wiki/config.json`
- `$(git rev-parse --git-common-dir)/llm-wiki/refresh-disabled`
- `$(git rev-parse --git-common-dir)/llm-wiki/consecutive-failures`
- `$(git rev-parse --git-common-dir)/llm-wiki/pending/`
- `$(git rev-parse --git-common-dir)/llm-wiki/failed/`
- `refs/llm-wiki/sources/`

When the project is bootstrapped, resolve the canonical upgrade script relative
to `../upgrade/SKILL.md` and run it with `--check`. Report exit status `10` as
`upgrade available`, not as an error. Do not apply the project migration unless
the user explicitly asks to update or upgrade the project-local structure.

## Rules

- Detect whether the user is running Claude Code, Codex, Pi, OpenClaw, or multiple CLIs are present.
- If the user asks only how to update, give commands without changing anything.
- If the user asks to check the latest version, fetch marketplace or package metadata and compare versions.
- If the user asks to update, run the update command for the active tool and tell them to restart the tool afterward.
- Compare semantic versions with `sort -V` when available; otherwise parse major/minor/patch numerically. Do not compare version strings lexicographically.
- If network access, marketplace metadata, or package metadata is unavailable, report the local version and the command that refreshes the relevant metadata.
- If `.llm-wiki/config.json` exists, report `headless_agent`, `context_agents`, and `main_wiki_path`.
- Report project structure as `current`, `upgrade available`, or `unknown` from the bundled upgrade check.
- Inspect refresh state in the shared Git directory. Always count runnable
  pending records, hidden interrupted queue records, and quarantined source
  records, even when `refresh-disabled` is absent. Report the breaker reason
  verbatim when present; `backlog:<n>` means the automatic pending-source bound
  opened the circuit before a provider launch, while `deferred:<n>` means work
  arrived outside the last bounded batch and needs an operator-paced retry.
  Report the circuit as `closed`
  only when the breaker is absent and the quarantined count is zero; otherwise
  report `open` with the breaker reason, consecutive-failure count, all three
  queue counts, queued-source keepalive-ref count, `post-commit-refresh.log`
  path, and exact recovery command
  `.llm-wiki/post-commit-refresh.sh --retry-failed all`. Do not invoke recovery
  unless the user explicitly asks to retry. Recovery processes one bounded
  batch per invocation, so say when the command must be rerun for remaining
  sources.
- Report managed wiki context using the exact `<!-- BEGIN LLM WIKI -->` and `<!-- END LLM WIKI -->` marker pair.
- Classify `AGENTS.md` and `CLAUDE.md` context as `managed present`, `unmanaged wiki section only`, `missing`, or `unknown`.
- Report Pi context from `AGENTS.md`; do not require `.pi/SYSTEM.md` or `.pi/APPEND_SYSTEM.md`.
- Report whether Claude SessionStart context appears configured when `.claude/settings.json` exists.
- Report OpenClaw context from the configured workspace's `AGENTS.md` and confirm that the project root matches that workspace before calling it present.
- Classify each automation surface as `codex`, `claude`, `pi`, `openclaw`, `mixed`, `missing`, `mismatch`, or `unknown`.
- For the scheduler and legacy post-commit scripts, ownership is clean only when
  the configured owner command is present and the non-owner commands are absent.
  `codex` means `codex exec` alone is present; `claude` means `claude -p` alone
  is present; `pi` means `pi -p` or `pi --print` alone is present; and
  `openclaw` means `openclaw agent --local --agent <openclaw_agent_id>` alone is
  present. The OpenClaw command must use the configured project-workspace agent
  ID and omit `--deliver` plus all channel, reply, and recipient flags. More
  than one owner command is `mixed`; exactly one command for a different
  configured owner is `mismatch`.
- The canonical post-commit template is different by design: it contains all
  four provider commands behind a runtime `headless_agent` dispatcher. Resolve
  `../../templates/post-commit-refresh.sh` relative to this SKILL.md. When the
  project copy is byte-for-byte equal to that bundled template, classify its
  owner from a validated `.llm-wiki/config.json` value (`codex`, `claude`, `pi`,
  or `openclaw`), not by scanning provider command tokens. For OpenClaw also
  require a valid `openclaw_agent_id`. An absent or unsupported configured owner
  is `unknown`. Use the command-token rules only for a non-canonical legacy
  post-commit script.
- The managed hook should invoke the canonical runner under the shared Git
  directory with `--project` and the committing worktree root. Report
  checkout-local-only invocation as `upgrade available`, because linked
  worktrees can otherwise retain stale ignored scripts.
- Count managed `llm-wiki` hook or scheduler entries when possible. The
  canonical dispatcher is clean only when exactly one managed hook block calls
  it; report missing or duplicate managed entries instead of treating the
  dispatcher itself as proof that the hook is healthy.
- Report exactly one project upgrade command for the active agent surface:
  `/llm-wiki:upgrade` for Claude Code, `$llm-wiki:upgrade` for Codex, or
  `/skill:wiki-upgrade` for Pi, or `wiki-upgrade` for OpenClaw. If the active
  surface cannot be determined, report the command as `unknown`; do not list
  all four alternatives.

## Claude Code

Useful commands:

```bash
claude plugin marketplace update aikuznetsov-marketplace
claude plugin update llm-wiki
claude plugin list --json --available
```

Status workflow:

1. Run `claude plugin list --json --available` when available.
2. Find `llm-wiki` by `name`, `id`, or `plugin` fields.
3. Compare installed/current and available/latest versions.
4. If a newer version exists, suggest:

```bash
claude plugin marketplace update aikuznetsov-marketplace
claude plugin update llm-wiki
```

Tell the user that Claude Code must be restarted for the updated plugin to load.

## Codex

Codex currently exposes marketplace refresh, not a first-class `plugin list` or `plugin update <plugin>` command.

Useful command:

```bash
codex plugin marketplace upgrade aikuznetsov-marketplace
```

Local version paths:

```bash
find ~/.codex/plugins/cache/aikuznetsov-marketplace/llm-wiki -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V | tail -n1
jq -r '.version' ~/.codex/.tmp/marketplaces/aikuznetsov-marketplace/plugins/llm-wiki/.codex-plugin/plugin.json
```

Remote marketplace check:

```bash
curl -fsSL https://raw.githubusercontent.com/ivankuznetsov/agent-plugins/main/.claude-plugin/marketplace.json \
  | jq -r '.plugins[] | select(.name == "llm-wiki") | .version'
```

Status workflow:

1. Read the local cached version from `~/.codex/plugins/cache/aikuznetsov-marketplace/llm-wiki/`.
2. Read the cached marketplace version from `~/.codex/.tmp/marketplaces/aikuznetsov-marketplace/plugins/llm-wiki/.codex-plugin/plugin.json` when it exists.
3. Fetch the remote marketplace version with `curl` when the user wants to know whether a new release is out.
4. If the remote version is newer than the local cached version, suggest:

```bash
codex plugin marketplace upgrade aikuznetsov-marketplace
```

Tell the user that Codex must be restarted for the updated plugin to load.

## Pi

Pi uses Pi packages instead of the Claude/Codex plugin marketplace. The Pi package exposes prefixed skill names to avoid global `/skill:name` collisions:

```text
/skill:wiki-bootstrap
/skill:wiki-upgrade
/skill:wiki-research
/skill:wiki-plan
/skill:wiki-status
```

Useful commands:

```bash
pi --version
pi list
pi update git:github.com/ivankuznetsov/llm-wiki
pi update --extensions
```

Remote package version check:

```bash
curl -fsSL https://raw.githubusercontent.com/ivankuznetsov/llm-wiki/main/package.json \
  | jq -r '.version'
```

Status workflow:

1. Run `pi --version` when available.
2. Run `pi list` when available and look for an installed `llm-wiki` package or source.
3. Read the local package version from `package.json` when running from the `llm-wiki` checkout.
4. Fetch the remote package version from the GitHub `package.json` when the user wants to know whether a new release is out.
5. If the remote version is newer than the installed/local version, suggest:

```bash
pi update git:github.com/ivankuznetsov/llm-wiki
```

If Pi reports the package under a different installed source, use that exact source with `pi update <source>`. Tell the user to restart Pi after updating package skills.

## OpenClaw

OpenClaw discovers this package through its Claude-compatible marketplace support and exposes the collision-safe `wiki-bootstrap`, `wiki-upgrade`, `wiki-research`, `wiki-plan`, and `wiki-status` skills.

Useful commands:

```bash
openclaw --version
openclaw agents list --json
openclaw plugins list --json
openclaw plugins inspect llm-wiki --json
openclaw plugins update llm-wiki --dry-run
openclaw plugins update llm-wiki
openclaw gateway restart --safe
```

Remote marketplace version check:

```bash
curl -fsSL https://raw.githubusercontent.com/ivankuznetsov/agent-plugins/main/.claude-plugin/marketplace.json \
  | jq -r '.plugins[] | select(.name == "llm-wiki") | .version'
```

Status workflow:

1. Run `openclaw --version` and `openclaw plugins list --json` when available.
2. Find the entry whose `id` or `name` is `llm-wiki`; use its `version`, `source`, and `rootDir` fields as the installed-state evidence. Use `openclaw plugins inspect llm-wiki --json` for a focused view when the plugin is discovered.
3. Run `openclaw agents list --json` when `.llm-wiki/config.json` names OpenClaw as the headless owner. Verify that `openclaw_agent_id` exists and its reported `workspace` resolves to the project root; otherwise classify automation as `mismatch`.
4. Fetch the remote version from the central marketplace manifest when the user wants to know whether a new release is out.
5. Before changing anything, run `openclaw plugins update llm-wiki --dry-run` to verify that the installed plugin is tracked and updatable.
6. If a newer version exists and the dry run succeeds, update with:

```bash
openclaw plugins update llm-wiki
```

If OpenClaw reports that a path-installed plugin is not tracked, do not claim it was updated. Reinstall from the same trusted local path or marketplace source shown by the user's installation evidence; the marketplace form supported by the CLI is `openclaw plugins install llm-wiki --marketplace ivankuznetsov/agent-plugins --force`.

After an update, a running Gateway must reload the plugin and skills. Request OpenClaw's bounded, work-aware service restart:

```bash
openclaw gateway restart --safe
```

Do not use `--force` for the Gateway restart by default. If no Gateway service is running and the user only uses one-shot local agent commands, report that the next process starts from the updated registry and no service restart is required.

## Report Format

Return:

```markdown
**llm-wiki Plugin Status**
- Current cached/installed version: ...
- Latest marketplace/package version: ...
- Status: current | update available | unknown
- Update command: ...
- Restart required: yes | no
- Headless agent: claude | codex | pi | openclaw | unknown
- OpenClaw agent id: ... | not configured | not applicable
- Context agents: ...
- AGENTS.md wiki context: managed present | unmanaged wiki section only | missing | unknown
- CLAUDE.md wiki context: managed present | unmanaged wiki section only | missing | unknown
- Pi wiki context: AGENTS.md managed present | missing | unknown
- OpenClaw wiki context: AGENTS.md managed present | workspace mismatch | missing | unknown
- Claude SessionStart context: present | missing | not checked
- Scheduled refresh owner: claude | codex | pi | openclaw | mixed | missing | mismatch | unknown
- Post-commit refresh owner: claude | codex | pi | openclaw | mixed | missing | mismatch | unknown
- Project structure: current | upgrade available | unknown
- Project upgrade command: <active surface's single command> | unknown
- Refresh circuit: closed | open (reason: <value>, failures: <n>, pending: <n>, interrupted: <n>, quarantined: <n>, pinned: <n>) | unknown
- Refresh recovery command: .llm-wiki/post-commit-refresh.sh --retry-failed all | not needed | unknown
- Refresh log: <shared-git-dir>/llm-wiki/post-commit-refresh.log | unknown
```

Mention whether the result came from local cache only or from a remote marketplace/package check.
