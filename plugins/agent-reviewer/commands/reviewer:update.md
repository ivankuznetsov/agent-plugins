# Update a Reviewer Persona

Refresh an existing persona with newer history, or widen its scope by adding a repo. Adding a second (or third) repo is the high-value move: it calibrates the persona — separating the reviewer's universal standards from the ones a single codebase happened to draw out.

## Usage

```text
/reviewer:update <login>                       # refresh from the persona's current repo scope
/reviewer:update <login> --add-repo <repo>     # widen scope: add a repo, re-extract, re-calibrate
/reviewer:update <login> --since <YYYY-MM-DD>   # change the history window, then refresh
```

## Prerequisites

- An existing `personas/<login>.md` with a scope block (built by `/reviewer:extract`). If it has no scope block, treat this as a fresh `/reviewer:extract` and tell the user.
- `gh` authenticated, `jq`. Run from where the relevant repos are checked out (the profiler reads the code).

## Behaviour

### 1. Read the current scope

Parse the YAML scope block at the top of `personas/<login>.md`:

```yaml
reviewer: <login>
repos: [<org/repo>, ...]
since: <YYYY-MM-DD>
comments: <N>
built: <YYYY-MM-DD>
```

Report it back: "This persona was built from <repos> over <since>, <N> comments, on <built>." Confirm what the update should do.

### 2. Determine the new scope

- **Refresh** (no flags): same repos, same window — picks up reviews merged since the persona was built.
- **`--add-repo <repo>`**: append the repo to the scope. Confirm the reviewer is actually a significant reviewer there first (`rank-reviewers.sh` on that repo); if they barely review it, say so and let the user decide.
- **`--since`**: change the window.

### 3. Re-collect

Run `collect-context.sh` for the reviewer across the **full** new repo set (re-collect all repos, not just the new one — simplest correct path; the script is cheap relative to extraction):

```bash
ORG=<org> REPOS="<all repos in new scope>" SINCE=<since> \
  "${CLAUDE_PLUGIN_ROOT}/scripts/collect-context.sh" <login>
```

### 4. Re-extract

Dispatch `reviewer-profiler` with the full context and **all scoped repos checked out**. Because the scope now spans multiple repos, the profiler will tag each concern `[all repos]` / `[repo-specific]` — that calibration is the point of widening scope. Have it overwrite `personas/<login>.md`, including a refreshed scope block.

### 5. Report the diff

Tell the user what changed versus the previous persona — new concerns the added repo surfaced, traits that turned out to be repo-specific (so they were over-weighted before), and anything the refresh strengthened or dropped. This is the payoff of the update: the user sees the persona get *more accurate*, not just larger.

## Notes

- Widening scope is how a persona stops overfitting one codebase. A persona built from a single repo cannot tell "what this reviewer always cares about" from "what this repo made them care about." The second repo fixes that — surface it explicitly to the user.
- Keep the persona file the source of truth: scope block + prose, hand-editable. `update` rewrites both.
