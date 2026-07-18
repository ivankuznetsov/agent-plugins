---
name: agent-reviewer
description: Clone your team's best code reviewers from their pull-request history and run them as a review panel. Use when the user wants to build or update a custom code reviewer from their team's review history, extract a reviewer's persona/style from past PR comments, mine GitHub review history for what reviewers care about, or review code in the voice of specific teammates. Ranks the prominent reviewers in a repo, collects each one's comments in context (the diff they were left on, the PR's intent), and extracts a persona per reviewer — what they care about, what they catch, what they let slide, how they sound — rather than a deterministic rule list. Each persona becomes a reviewer agent; run them together as a panel. In Codex this skill is the entry point; in Claude Code the same flows are also the /reviewer:extract, /reviewer:review, and /reviewer:update commands.
---

# Agent Reviewer

Your team has already written thousands of near-perfect reviews. They're sitting in GitHub as dead weight. Agent Reviewer reads that history and turns your best reviewers into a panel of agents that review new code the way they do.

The load-bearing idea is to extract the **person**, not a rule list. A rule list is a frequency table of vocabulary: it can say that a reviewer asks for renames often, but not that they only care about names on public APIs or forgive almost anything except a silently swallowed error. Read comments with the code and PR intent they responded to, then capture what the reviewer cares about, catches, lets slide, and how they sound.

## Installed resources and working files

Resolve bundled resources relative to this canonical skill file, even when the plugin has been copied into an isolated installation. Do not assume a repository-root checkout or a host-specific variable such as `CLAUDE_PLUGIN_ROOT`:

- [rank-reviewers.sh](../../scripts/rank-reviewers.sh)
- [collect-context.sh](../../scripts/collect-context.sh)
- [reviewer-profiler agent](../../agents/reviewer-profiler.md)
- [persona-reviewer agent](../../agents/persona-reviewer.md)
- [finding schema](../../references/finding-schema.md)

The generated `context-<login>.json` files and `personas/<login>.md` files belong in the invocation working directory, not inside the installed plugin package. Run from a checked-out target repository, with every repository in scope available to the profiler. Extraction and update require authenticated `gh` (`gh auth status`) and `jq`; report a missing prerequisite and stop before collection.

## Choose the workflow

Select the workflow from the user's request or from the mode supplied by a compatibility entry point. Preserve these argument grammars:

```text
extract [<login> ...]
review [<target>] [--only <login>] [--passes <N>] [--min-confidence <0..1>]
update <login> [--add-repo <repo>] [--since <YYYY-MM-DD>]
```

Claude Code exposes the same modes as `/reviewer:extract`, `/reviewer:review`, and `/reviewer:update`. Other hosts invoke this skill and state the desired mode naturally. Do not reinterpret or discard arguments passed by an adapter.

## Extract personas

Set the scope with one organization and one or more repositories. All repositories in a run must share the organization. Obtain `ORG`, `REPOS`, and the desired `SINCE` date from the invocation environment or the user before collecting.

### 1. Select reviewers

Run the bundled ranking script across the entire scope:

```bash
ORG=<org> REPOS="<repo1> <repo2>" \
  <installed-plugin-root>/scripts/rank-reviewers.sh
```

The script marks significant reviewers with ★ at or above `SIGNIF_PCT` (default 25% of the top reviewer's volume).

When one or more logins are supplied, treat those logins as the final selection and **skip the selection dialog**. The ranking provides volume context only; do not ask the user to choose the supplied reviewers again and do not wait for confirmation.

When no login is supplied, show the ranking and make selection a dialog, never an automatic top-name pick:

- If exactly one reviewer is significant, propose that persona and ask for confirmation.
- If several are significant, name them and propose one persona per reviewer, run as a panel.
- Remind the user that volume is not taste: they may drop a high-volume reviewer or add a lower-volume reviewer whose judgment they value.
- Wait for the user's selection before collecting.

### 2. Collect full context for every selected reviewer

For each reviewer, run the bundled collector over the complete repo scope:

```bash
ORG=<org> REPOS="<repo1> <repo2>" SINCE=<YYYY-MM-DD> \
  <installed-plugin-root>/scripts/collect-context.sh <login>
```

It writes `context-<login>.json` in the working directory. The required evidence is each comment with its diff hunk, path, PR title/intent, repository, and reply pointer. The scripts define the minimum shape, not a hard ceiling: adapt the `gh` query when the organization represents reviews differently, and collect reply threads where reviewers held their ground. If a reviewer has very few comments, warn that the resulting persona will be thin.

### 3. Profile one person at a time

For each selected login, load the bundled `reviewer-profiler` definition and dispatch a separate profiler with:

- the login and `context-<login>.json`;
- access to every scoped repository checkout;
- the instruction to read the code to ground every observation; and
- the output path `personas/<login>.md`, including the YAML scope block (`reviewer`, full `repos`, `since`, `comments`, `built`).

Run independent reviewers in parallel when the host supports it. Never merge several people into one "team" persona. With multiple repositories, require `[all repos]` and `[repo-specific]` calibration; with one repository, record that cross-repo calibration is still low confidence.

### 4. Report extraction

List every persona written, give a one-line summary of what that reviewer cares about, and explain that the markdown is hand-editable. Point the user to the review workflow next.

## Review with the persona panel

### Arguments and defaults

Accept one optional target plus options in any order:

```text
review [<target>] [--only <login>] [--passes <N>] [--min-confidence <0..1>]
```

- `--only <login>` selects one persona instead of the whole panel.
- `--passes <N>` must be a positive integer and defaults to `2`.
- `--min-confidence <0..1>` must be within the inclusive range 0 through 1 and defaults to `0.5`.

Report an unknown option, missing option value, invalid pass count, out-of-range confidence, or multiple positional targets and stop before dispatching reviewers.

### 1. Resolve the target with fixed precedence

Use the first available source in this order:

1. The explicit `<target>` argument, which always wins. It may identify a file, diff, commit/range, or PR.
2. An open PR for the current branch.
3. The current working-tree `git diff`.
4. Other uncommitted changes, including staged and untracked files, assembled into a reviewable change.

If none contains a change, report that there is nothing to review and stop. Do not dispatch an empty panel or invent a target.

### 2. Resolve the panel

List `personas/*.md` in the invocation working directory. If none exist, report that no reviewer personas are available, point the user to the extract workflow, and stop.

With `--only <login>`, require `personas/<login>.md`; if it does not exist, report the missing persona and stop rather than silently using the full panel. Without `--only`, use every persona file as a distinct panel member.

### 3. Build one whole-change packet

Build the complete packet once, then give the same whole-change packet to every independent pass. Include:

- the resolved target and PR intent when applicable;
- the complete diff or PR, not an isolated hunk;
- the full changed-file list and file paths; and
- enough local repository context to judge helper reuse, moved code, tests, logging ownership, error handling, and consistency across the whole change.

If the explicit target is one file, still include the surrounding changed-file list when available. Run every reviewer with the repository checked out and permission to read/search it. Repository access is part of the review contract.

### 4. Run independent passes for each persona

For every selected persona, load the bundled `persona-reviewer` definition and dispatch exactly `N` separate invocations on the same packet, where `N` is `--passes` or the default `2`. Passes are independent: do not seed a later pass with an earlier pass's findings. A one-pass request is the faster, lower-recall mode; three or more passes accumulate more possible findings.

Before returning, **every pass** must perform the miss-class sweep that hunk-only review tends to miss:

- missing tests;
- missing validation or limits;
- move/delete/add directives and incomplete moves;
- wrong logging or error-handling direction; and
- naming and test-style nits.

The persona adds only findings supported by its history. Require every pass to serialize findings using the bundled finding schema, including per-finding confidence.

### 5. Union, deduplicate, then apply the confidence gate

Process each persona's passes in this exact order:

1. Union all findings from all of that persona's passes.
2. Deduplicate findings that express the same concern on the same file and line. Keep the clearest wording and note pass agreement; do not collapse genuinely distinct concerns merely because they share a line.
3. Apply the confidence gate to the unioned set: drop findings whose `confidence` is below `--min-confidence` (default `0.5`).

Do not confidence-gate individual passes before the union, and do not replace the numeric gate with a generic instruction to "be cautious."

### 6. Consolidate the panel

Merge the gated per-persona sets into one report grouped by severity: 🔴 Critical, 🟡 Important, and 🔵 Nice-to-have. Tag every finding with the persona that raised it. When multiple personas flag the same concern or line, retain the distinct voices and note the agreement as a strong signal. Do not flatten the panel into generic lint advice. If every gated set is empty, report that the panel found no issues by these personas' standards.

## Update a persona

Use update to refresh an existing persona from newer history or widen it to another repository:

```text
update <login>
update <login> --add-repo <repo>
update <login> --since <YYYY-MM-DD>
```

`--add-repo` and `--since` may be combined. Require a login, validate the date format, and reject missing option values or unknown options before collecting.

### 1. Read and confirm the stored scope

Read `personas/<login>.md` and parse its YAML scope block:

```yaml
reviewer: <login>
repos: [<org/repo>, ...]
since: <YYYY-MM-DD>
comments: <N>
built: <YYYY-MM-DD>
```

Validate that the file's `reviewer` matches `<login>`. Report the current repos, history window, comment count, and build date, then confirm the intended refresh or scope change. If the persona is missing or its scope block is absent/invalid, explain that update cannot safely reconstruct its scope and route this as a fresh extract instead; do not guess and overwrite the file.

### 2. Validate the new scope

- With no flags, retain the same repositories and `since` date. A refresh still re-collects the entire window so newer reviews are included.
- With `--since`, replace the stored history-window start.
- With `--add-repo`, verify that the repository is accessible, belongs to the same organization as the stored scope, and is not already present. Run the bundled ranking script on that repository and validate that `<login>` reviews there. If the reviewer is absent or below the significant-volume line, show the evidence and let the user decide whether to continue; stop pending that decision rather than silently widening the persona.

Append an approved repository to the full scope. Never replace the old repo set with only the added repository.

### 3. Re-collect the full new scope

Run the bundled collector once for `<login>` across **all repositories in the resulting scope**, using the resulting `since` date. Do not collect only the added repository and do not incrementally splice histories; full recollection is the simplest correct input to recalibration.

### 4. Re-extract and overwrite

Keep the previous persona available for comparison. Dispatch the bundled `reviewer-profiler` with the newly collected full context and all scoped repository checkouts. Instruct it to overwrite exactly `personas/<login>.md` with both a refreshed scope block and refreshed prose. Multi-repo updates must recalibrate concerns as `[all repos]` or `[repo-specific]`.

### 5. Report the persona delta

Compare the old and new personas and report:

- new concerns surfaced by new history or the added repo;
- concerns now shown to be repo-specific and therefore previously over-weighted;
- traits whose evidence was strengthened;
- traits weakened or dropped; and
- the old and new scope/comment/build metadata.

If the prose did not materially change, say so explicitly. The update is successful only when the user sees how the persona changed, not merely that the file was overwritten.

## Principles

- **Persona, not rules.** Always extract the person.
- **Context or it didn't happen.** The profiler and reviewers read the codebase, not just comments or diff hunks.
- **One voice per reviewer.** Never merge reviewers into a single team persona.
- **Narrow beats broad.** Distinct, opinionated personas reviewing as a panel beat one agent that flags everything.
- **Never invent standards.** Ground every persona claim and review finding in the history or code; flag thin spots honestly.
