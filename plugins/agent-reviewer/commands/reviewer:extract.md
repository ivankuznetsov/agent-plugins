# Extract Reviewer Personas

Turn your team's pull-request review history into a panel of reviewer personas. Ranks the people who do the reviews that matter across **one or more repos**, collects each one's comments in context, and extracts a persona per reviewer — what they care about, what they catch, what they let slide, how they sound. Personas, not rule lists.

Pointing it at several repos isn't just more data — it *calibrates* each persona, separating the reviewer's universal standards from the ones a single codebase drew out. (To widen an existing persona's scope later, use `/reviewer:update --add-repo`.)

## Usage

```text
/reviewer:extract                         # discover reviewers across the repo set, then extract the ones you pick
/reviewer:extract <login> [<login> ...]   # extract these specific reviewers
```

Set the repo scope with `ORG` + `REPOS` (one or many): `ORG=acme REPOS="api worker gateway"`. All repos in a single run should share an org.

## Prerequisites

- `gh` authenticated (`gh auth status`), `jq` installed.
- Run from inside the target repository (or a directory where the repo is checked out) — the profiler reads the codebase, not just the comments.

## Behaviour

### 1. Discover the reviewers, then have a dialog (skip the dialog only if logins were given)

Run the ranking script over the repos you care about:

```bash
ORG=<org> REPOS="<repo1> <repo2>" \
  "${CLAUDE_PLUGIN_ROOT}/scripts/rank-reviewers.sh"
```

The script flags the reviewers whose contribution is **significant** (★ — at or above `SIGNIF_PCT`, default 25% of the top reviewer's volume) and prints a suggestion.

**This step is a dialog, not an auto-pick.** Show the ranked list, then:

- **If exactly one reviewer is significant**, propose building that single persona and confirm.
- **If more than one is significant**, this is the important case: *say so explicitly and propose a persona for each, run as a panel.* For example: "Three reviewers here have significant volume — the top one (100%), the next (83%), and a third (52%). I'd suggest a persona for each so the panel reflects how this repo is actually reviewed. Want all three, a subset, or should I add someone below the line?"
- Remind them volume isn't taste — they can drop a high-volume reviewer or add a lower-volume one whose judgment they value.
- **Wait for the user's decision.** Build one persona per chosen reviewer; never silently profile only the top name when several are significant.

### 2. Collect context, per reviewer

For each chosen reviewer, gather their comments *with the diff and PR intent attached*:

```bash
ORG=<org> REPOS="<repo1> <repo2>" SINCE=<YYYY-MM-DD> \
  "${CLAUDE_PLUGIN_ROOT}/scripts/collect-context.sh" <login>
```

This writes `context-<login>.json`. If a reviewer has very few comments, say so — a thin history makes a thin persona.

### 3. Extract a persona, per reviewer

Dispatch one `reviewer-profiler` subagent per reviewer. Give it the login, the context file, and access to **all scoped repos checked out**:

```text
Task reviewer-profiler("Profile reviewer <login>. Context: context-<login>.json.
Repos in scope are checked out here: <list> — read them to ground every observation.
Write personas/<login>.md, including the scope block (repos, since, comments, built).")
```

When the scope spans more than one repo, the profiler tags each concern `[all repos]` / `[repo-specific]` — that calibration is the main reason to point it at several repos. With a single repo it notes in "Low confidence" that it can't calibrate yet, and that `/reviewer:update --add-repo` would.

Run them in parallel when you have several. Each writes `personas/<login>.md`.

### 4. Report

List the personas written, with a one-line summary of what each reviewer cares about. Tell the user they can now run `/reviewer:review` to review changes with the panel, and that the persona files are plain markdown they can edit by hand.

## Notes

- The collection scripts are a starting shape, not gospel — if the org tags reviews differently, adapt the `gh` queries (Claude can extend them to pull full reply threads or PR bodies).
- One persona per reviewer. Don't merge several reviewers into one "team" persona — the value is in distinct, narrow voices reviewing as a panel.
