---
name: agent-reviewer
description: Clone your team's best code reviewers from their pull-request history and run them as a review panel. Use when the user wants to build a custom code reviewer from their team's review history, extract a reviewer's persona/style from past PR comments, mine GitHub review history for what reviewers care about, or review code in the voice of specific teammates. Ranks the prominent reviewers in a repo, collects each one's comments in context (the diff they were left on, the PR's intent), and extracts a persona per reviewer — what they care about, what they catch, what they let slide, how they sound — rather than a deterministic rule list. Each persona becomes a reviewer agent; run them together as a panel. In Codex this skill is the entry point; in Claude Code the same flows are also the /reviewer:extract and /reviewer:review commands.
---

# Agent Reviewer

Your team has already written thousands of near-perfect reviews. They're sitting in GitHub as dead weight. Agent Reviewer reads that history and turns your best reviewers into a panel of agents that review new code the way they do.

The load-bearing idea: extract the **person**, not a rule list. A rule list is a frequency table of vocabulary — it tells you a reviewer says "rename this" a lot; it can't tell you they only care about names on the public API, or that they'll forgive anything except a silently swallowed error. The signal worth cloning is what a keyword count throws away. So we read each reviewer's comments *in the context of the code they were reviewing* and capture their judgment: what they care about, what they catch, what they let slide, how they sound.

This is the Base44 onboarding prompt — *"look at the project, the commit history, the reviews, and tell me what the people working on this codebase care about"* — pointed at one reviewer instead of the whole team.

## The pipeline

Four phases. One persona per reviewer; run them as a panel.

### 1. Pick the reviewers — as a dialog

A repo usually has more than one person doing the reviews that matter. Rank them:

```bash
ORG=<org> REPOS="<repo1> <repo2>" \
  "${CLAUDE_PLUGIN_ROOT}/scripts/rank-reviewers.sh"
```

The script marks the **significant** reviewers (★ — at/above `SIGNIF_PCT`, default 25% of the top reviewer's volume). **Don't auto-pick — open a dialog:**

- Show the ranking with the significance marks.
- **If several reviewers are significant, name them and propose a persona for each, run as a panel** — that's the whole point of the panel model. ("Three reviewers here clear the bar — want a persona for each?")
- Volume isn't taste: invite the user to drop a high-volume name or add a lower-volume one they value.
- Wait for their decision. Build one persona per chosen reviewer. Never silently profile only the top name when several are significant — surfacing the second and third reviewer is the job.

### 2. Collect the context

For each chosen reviewer, gather their comments *with the diff they were left on and the PR's intent* — because a reviewer's standards live in the gap between what the code did and what they wanted, not in the comment alone:

```bash
ORG=<org> REPOS="<repo1> <repo2>" SINCE=<YYYY-MM-DD> \
  "${CLAUDE_PLUGIN_ROOT}/scripts/collect-context.sh" <login>
```

Writes `context-<login>.json`. The scripts are the *shape* of what's needed, not gospel — adapt the `gh` queries to how the org tags reviews; extend them to pull reply threads (`in_reply_to`) where reviewers held their ground, which is where their strongest standards live.

### 3. Extract the persona

This is the heart. Dispatch a `reviewer-profiler` subagent per reviewer, with the context file **and the repository checked out** — the profiler must read the codebase to make sense of comments like "we already have a helper for this":

```text
Task reviewer-profiler("Profile reviewer <login>. Context: context-<login>.json.
The repo is checked out here — read it to ground every observation.
Write personas/<login>.md.")
```

Each writes `personas/<login>.md`: a first-person portrait in the reviewer's voice, with concrete preferences, each backed by a real quote and real code context.

### 4. Review as a panel

Dispatch a `persona-reviewer` subagent per persona on the change under review, then consolidate by severity with each finding tagged by persona:

```text
Task persona-reviewer("Persona: personas/<login>.md. Review: <diff/PR/file>.")
```

Keep the voices distinct. A panel works because each reviewer is narrow and real; if every persona flags everything, you've rebuilt the industry-average reviewer you were trying to escape.

## Scope: one repo or many

`ORG` + `REPOS` set the scope; `REPOS` can list several repos that share an org. Pointing at more than one repo is not just more data — it **calibrates** the persona. A persona built from a single repo cannot tell the reviewer's universal standards from the ones that codebase happened to draw out, so it silently over-generalizes. With two or more repos the profiler tags each concern `[all repos]` vs `[repo-specific]` — that's the difference between cloning *the person* and cloning *the person on one project*. The rank step also aggregates across the whole repo set, so "prominent reviewers" means prominent across everything in scope.

## Updating a persona

A persona is a living artifact with a scope block (repos, history window, build date) at the top. Update it two ways:

- **Refresh** — re-run over the same repos to pick up new reviews since it was built.
- **Widen scope** — add a repo. This is the high-value update: it re-calibrates the persona and surfaces traits the new codebase exercises (and traits that turn out to be repo-specific, which were over-weighted before).

Exposed as `/reviewer:update <login> [--add-repo <repo>] [--since <date>]`.

## Claude Code commands

The same flows are exposed as commands:

- `/reviewer:extract [<login> ...]` — discover across the repo set, dialog, collect, profile.
- `/reviewer:review [<target>]` — run the persona panel.
- `/reviewer:update <login> [--add-repo <repo>]` — refresh or widen a persona's scope.

## Compound Engineering

The `compound-engineering` plugin already runs review as a *panel of personas* — it ships famous ones (`kieran-rails-reviewer`, `dhh-rails-reviewer`). The personas you extract are the same structure, but they're *your team*. Add them to that plugin's `/workflows:review` parallel-agents list alongside or instead of the stock reviewers.

## Principles

- **Persona, not rules.** Always extract the person.
- **Context or it didn't happen.** The profiler reads the codebase, not just comment text.
- **One voice per reviewer.** Never merge reviewers into a single "team" persona.
- **Narrow beats broad.** Distinct, opinionated personas reviewing as a panel beat one agent that flags everything.
- **Never invent standards.** Ground every persona claim in the history or the code; flag thin spots honestly.
