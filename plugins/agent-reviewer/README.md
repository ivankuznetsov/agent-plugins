# Agent Reviewer

Clone your team's best code reviewers from their pull-request history and run them as a review panel.

Your team has already written thousands of near-perfect reviews. They're sitting in GitHub as dead weight. Agent Reviewer reads that history and turns your best reviewers into agents that review new code the way they do — extracting the **person**, not a rule list.

A rule list is a frequency table of vocabulary: it tells you a reviewer says "rename this" a lot, but not that they only care about names on the public API, or that they'll forgive anything except a silently swallowed error. The signal worth cloning is what a keyword count throws away. So Agent Reviewer reads each reviewer's comments *in the context of the code they were reviewing* and captures their judgment — what they care about, what they catch, what they let slide, how they sound.

It's the Base44 onboarding prompt — *"look at the commit history and the reviews, and tell me what the people working on this codebase care about"* — pointed at one reviewer instead of the whole team.

## What it does

Four phases, one persona per reviewer, run as a panel:

1. **Pick** the prominent reviewers across your repo set (ranked by review volume; the skill flags the significant ones and asks you which to clone — a dialog, not an auto-pick).
2. **Collect** each reviewer's comments *with the diff they were left on and the PR's intent* — standards live in the gap between what the code did and what the reviewer wanted.
3. **Extract** a persona per reviewer with the codebase(s) checked out, so context-dependent comments make sense.
4. **Review** new changes with the personas as a panel, consolidated by severity, each finding tagged by reviewer.

### One repo or many

Point it at several repos and it does more than add data — it **calibrates** each persona. A persona built from a single repo can't tell a reviewer's universal standards from the ones that one codebase drew out, so it silently over-generalizes. With two or more repos, each concern is tagged `[all repos]` vs `[repo-specific]` — the difference between cloning *the person* and cloning *the person on one project*.

### Living personas

Each persona carries a scope block (repos, history window, build date) and can be updated:

- **Refresh** — pick up new reviews since it was built.
- **Widen scope** — add a repo to re-calibrate and surface what the new codebase exercises.

## Install

```text
/plugin marketplace add ivankuznetsov/agent-plugins
/plugin install agent-reviewer
```

Requires `gh` (authenticated) and `jq`. The optional eval harness also requires
`unshare` + `bwrap` for network and filesystem isolation, or an equivalent
external sandbox.

## Use

### Claude Code

```text
/reviewer:extract                       # discover reviewers across the repo set, then extract the ones you pick
/reviewer:extract katya mikhail         # extract specific reviewers
/reviewer:review                        # review current changes with the panel
/reviewer:review --only katya           # review with a single persona
/reviewer:update katya                  # refresh a persona from its current repo scope
/reviewer:update katya --add-repo api   # widen scope: add a repo, re-calibrate the persona
```

Set the repo scope with `ORG` + `REPOS` (one or many, same org): `ORG=acme REPOS="api worker gateway"`.

### Codex

Ask for Agent Reviewer: *"use Agent Reviewer to extract a persona for our top reviewer and review my current branch."* The `agent-reviewer` skill drives the same pipeline.

## What you get

- `context-<login>.json` — a reviewer's comments with diff + PR intent (intermediate).
- `personas/<login>.md` — a first-person portrait of the reviewer, with concrete preferences each backed by a real quote and real code context. Plain markdown; edit by hand anytime.

## Components

| Piece | Role |
|-------|------|
| `reviewer-profiler` (agent) | Reads one reviewer's history + the codebase, writes the persona. |
| `persona-reviewer` (agent) | Reviews a diff/PR as a given persona. |
| `scripts/rank-reviewers.sh` | Ranks reviewers by review volume. |
| `scripts/collect-context.sh` | Collects one reviewer's comments with diff + PR intent. |
| `/reviewer:extract`, `/reviewer:review` | Claude Code commands for the pipeline. |
| `skills/agent-reviewer/SKILL.md` | Codex entry point and the orchestration brain. |

## Compound Engineering

The [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin) plugin already runs review as a panel of personas — it just ships famous ones (`kieran-rails-reviewer`, `dhh-rails-reviewer`). The personas you extract have the same shape but are *your team*. Add them to its `/workflows:review` parallel-agents list alongside or instead of the stock reviewers.

## Principles

- **Persona, not rules.** Extract the person.
- **Context or it didn't happen.** The profiler reads the codebase, not just comment text.
- **One voice per reviewer.** Never merge reviewers into a single "team" persona.
- **Narrow beats broad.** Distinct, opinionated personas reviewing as a panel beat one agent that flags everything.
- **Never invent standards.** Ground every persona claim in the history or the code.

## Background

The thinking behind this plugin — and why persona extraction beats rule extraction — is written up in [Building your own code reviewer for Claude from your team's commit history](https://ikuznetsov.com).

## License

MIT
