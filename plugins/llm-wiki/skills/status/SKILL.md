---
name: status
description: Check whether the llm-wiki plugin is current, detect newer marketplace versions, and suggest or run the right update command for Claude Code or Codex. Use when the user asks about llm-wiki version, plugin updates, marketplace refresh, upgrade instructions, or whether a new llm-wiki release is available.
---

# LLM Wiki Status

Check whether `llm-wiki` is current and report the exact update command for the current agent environment.

Also inspect project-local wiki configuration when available:

- `.llm-wiki/config.json`
- `AGENTS.md`
- `CLAUDE.md`
- `.claude/settings.json`
- `.llm-wiki/refresh-wiki.sh`
- `.llm-wiki/post-commit-refresh.sh`

## Rules

- Detect whether the user is running Claude Code, Codex, or both CLIs are present.
- If the user asks only how to update, give commands without changing anything.
- If the user asks to check the latest version, fetch marketplace metadata and compare versions.
- If the user asks to update, run the update command for the active tool and tell them to restart the tool afterward.
- Compare semantic versions with `sort -V` when available; otherwise parse major/minor/patch numerically. Do not compare version strings lexicographically.
- If network access or marketplace metadata is unavailable, report the local version and the command that refreshes marketplace metadata.
- If `.llm-wiki/config.json` exists, report `headless_agent`, `context_agents`, and `main_wiki_path`.
- Report managed wiki context using the exact `<!-- BEGIN LLM WIKI -->` and `<!-- END LLM WIKI -->` marker pair.
- Classify `AGENTS.md` and `CLAUDE.md` context as `managed present`, `unmanaged wiki section only`, `missing`, or `unknown`.
- Report whether Claude SessionStart context appears configured when `.claude/settings.json` exists.
- Classify each automation surface as `codex`, `claude`, `mixed`, `missing`, `mismatch`, or `unknown`.
- Scheduler and post-commit ownership are clean only when the configured owner command is present and the non-owner command is absent.
- `codex` means `codex exec` is present and `claude -p` is absent.
- `claude` means `claude -p` is present and `codex exec` is absent.
- `mixed` means both commands are present.
- `mismatch` means exactly one owner command is present but it is not the configured `headless_agent`.
- Count managed `llm-wiki` hook or scheduler entries when possible; report duplicates as `mixed` or `mismatch` rather than clean.

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

## Report Format

Return:

```markdown
**llm-wiki Plugin Status**
- Current cached/installed version: ...
- Latest marketplace version: ...
- Status: current | update available | unknown
- Update command: ...
- Restart required: yes | no
- Headless agent: claude | codex | unknown
- Context agents: ...
- AGENTS.md wiki context: managed present | unmanaged wiki section only | missing | unknown
- CLAUDE.md wiki context: managed present | unmanaged wiki section only | missing | unknown
- Claude SessionStart context: present | missing | not checked
- Scheduled refresh owner: claude | codex | mixed | missing | mismatch | unknown
- Post-commit refresh owner: claude | codex | mixed | missing | mismatch | unknown
```

Mention whether the result came from local cache only or from a remote marketplace check.
