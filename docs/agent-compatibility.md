# Agent compatibility

Every shipped plugin is a self-contained package for Claude Code, Codex, Pi,
and OpenClaw. `plugins/<name>/skills/` is the behavioral source; checked-in Pi
and OpenClaw adapters load that source from inside the copied package.

## Tested hosts

The versions below are exact CI pins, not formal minimums. None of the four
upstreams currently specifies a formal minimum for this repository's plugin
shape, so the minimum remains explicitly unspecified.

ClawHub package metadata separately declares `>=2026.7.1-beta.2` as the
conservative OpenClaw plugin API floor because that is the host/API version
these packages were built and tested against.

| Host | CI-tested version | Formal minimum | Native check |
| --- | --- | --- | --- |
| Claude Code | `2.1.179` | Upstream does not specify one | Strict manifest/component validation from a copied package |
| Codex CLI | `0.144.3` | Upstream does not specify one | Marketplace install plus app-server `skills/list` |
| Pi | `0.80.10` | Upstream does not specify one | Package install/list plus RPC command discovery |
| OpenClaw | `2026.7.1-beta.2` | Upstream does not specify one | Native plugin install/inspect plus `skills check` |

OpenClaw packages contain a generated content-only JavaScript entry. It exists
solely to activate the manifest-declared skill directory; it registers no
tools, services, hooks, providers, or configuration side effects.

## Package inventory

All current packages are stable. Canonical files and resources stay inside the
plugin directory so a copied package does not depend on the repository root.

| Plugin | Version | Stability | Canonical skill source | Bundled resources |
| --- | --- | --- | --- | --- |
| Agent Reviewer | `0.3.1` | Stable | `skills/agent-reviewer/SKILL.md` | agents, references, scripts, eval harness |
| Agent SEO | `2.0.1` | Stable | `skills/seo/SKILL.md` | agents, context, data sources, hooks, scripts |
| Agent Writing | `0.5.2` | Stable | `skills/writing/SKILL.md` | agents, voice/style context |
| LLM Wiki | `0.3.5` | Stable | five files under `skills/` | assets, consent-gated maintenance templates |
| Screenote | `3.1.0` | Stable | `skills/{screenote,snapshot,feedback}/SKILL.md` | CLI launcher, references, evals |

## Plugin invocations

| Plugin | Claude Code | Codex | Pi | OpenClaw |
| --- | --- | --- | --- | --- |
| Agent Reviewer | `/reviewer:extract`, `/reviewer:review`, `/reviewer:update` | `$agent-reviewer:agent-reviewer` | `agent-reviewer` | `agent-reviewer` |
| Agent SEO | ten existing `/seo:*` commands | `$agent-seo:agent-seo` | `agent-seo` | `agent-seo` |
| Agent Writing | seven existing `/write:*` commands | `$agent-writing:agent-writing` | `agent-writing` | `agent-writing` |
| LLM Wiki | `bootstrap`, `upgrade`, `research`, `wiki-plan`, `wiki-status` | `$llm-wiki:<skill>` | `wiki-bootstrap`, `wiki-upgrade`, `wiki-research`, `wiki-plan`, `wiki-status` | `wiki-bootstrap`, `wiki-upgrade`, `wiki-research`, `wiki-plan`, `wiki-status` |
| Screenote | `/screenote`, `/snapshot`, `/feedback` | `$screenote:<skill>` | `screenote`, `snapshot`, `feedback` | `screenote`, `snapshot`, `feedback` |

## Installation shapes

- Claude Code installs from `.claude-plugin/marketplace.json`.
- Codex installs from `.agents/plugins/marketplace.json`.
- Pi installs a copied `plugins/<name>` directory and reads
  `package.json#pi.skills`.
- OpenClaw installs the same copied directory and reads `package.json#openclaw`,
  `openclaw.plugin.json`, and `openclaw/skills/`.

No generated file uses a symlink or a path outside its plugin directory.

## Reproducing CI discovery

Run deterministic checks without any host CLI:

```bash
python3 scripts/validate-agent-packages.py --inventory
python3 scripts/generate-agent-packages.py --check
python3 -m unittest discover -s tests -v
```

Run all installed native hosts at their exact pins:

```bash
REQUIRE_AGENT_CLI=1 bash scripts/smoke-agent-packages.sh all
```

Pass one of `claude`, `codex`, `pi`, or `openclaw` to exercise a single host.
The runner copies packages and catalogs to a private temporary directory and
uses isolated home/config roots. If a CLI is absent in an ordinary developer
run, it emits a structured skip; CI sets `REQUIRE_AGENT_CLI=1` so an absent or
version-drifted host fails.
