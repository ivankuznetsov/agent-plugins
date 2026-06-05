# Review With the Persona Panel

Review a diff or PR with your extracted reviewer personas, run as a panel — each persona commenting in their own voice and priorities, across two independent passes unioned, then consolidated.

## Usage

```text
/reviewer:review                  # review the current diff / uncommitted changes (2 passes, unioned)
/reviewer:review <file-or-PR>     # review a specific file, or an open PR
/reviewer:review --only <login>   # run a single persona instead of the whole panel
/reviewer:review --passes 1       # faster, single pass (lower recall — see Notes)
/reviewer:review --passes 3       # more passes unioned (higher recall, more false positives)
```

## Prerequisites

- Personas extracted into `personas/*.md` (run `/reviewer:extract` first). If none exist, say so and point at `/reviewer:extract`.

## Behaviour

1. **Resolve what to review.** An explicit argument wins. Otherwise: an open PR for the branch, else the current `git diff`, else uncommitted changes. If nothing's there, ask.
2. **Find the panel.** List `personas/*.md`. With `--only <login>`, use just that one.
3. **Build a whole-change review packet.** Give each persona the full PR/diff context, not only one isolated hunk. Include the complete diff or PR, changed-file list, file paths, and any local repo context needed to understand helper reuse, moved code, tests, logging ownership, and "по всему PR" consistency. If the target is one file, still include the surrounding changed-file list when available so cross-file consistency is visible. The `persona-reviewer` runs with the repository checked out and `Read`/`Grep`/`Glob` — repository access is the single biggest lever, so never strip it.
4. **Run the panel — two passes by default, unioned.** For each persona, dispatch the `persona-reviewer` subagent **twice** (two independent passes) on the same whole-change packet. The model is stochastic: each pass surfaces a slightly different subset of the real issues, so unioning the passes is the largest recall lever there is — it is exactly what the eval's "full recipe" measures, and what carries the benchmark from ~31% (single pass) to ~42% (two passes unioned). Honor `--passes N` (default 2); `--passes 1` is the fast, lower-recall mode.

   ```text
   Task persona-reviewer("Persona: personas/<login>.md. Review packet: <whole diff/PR + changed files + target>.")   # ×N passes per persona
   ```

   Each pass must run the **miss-class sweep** before returning: the classes reviewers miss when only reading hunks — missing tests, missing validation or limits, move/delete/add directives, wrong logging/error-handling direction, naming/test-style nits. The persona adds only findings its history supports.
5. **Union each persona's passes, gated by confidence.** Merge a persona's passes into one set: findings that are the *same concern on the same line* collapse to a single finding (keep the clearer wording and note the agreement); genuinely distinct findings accumulate. Then apply the confidence gate from the finding schema — drop findings below `--min-confidence` (default 0.5). Unioning raises recall but also false positives, so the gate is what holds precision; on the eval it cut false positives with no loss of recall, where a blanket "be cautious" instruction just made the reviewer timid.
6. **Consolidate across personas.** Merge the panel into one report, grouped by severity (🔴 Critical / 🟡 Important / 🔵 Nice-to-have), each finding tagged with the persona who raised it. Where two personas flag the same line, note the agreement — that's a strong signal. Keep distinct voices distinct; don't flatten them into a generic review.

## Notes

- **Why two passes by default.** A single pass is cheaper but leaves recall on the table; on the internal benchmark the same persona scored ~31% single-pass and ~42% with two passes unioned (both with the repo checked out). We default to the recipe we actually benchmark, so the number you read is the number you run. Drop to `--passes 1` when you want speed over coverage.
- A panel works because each persona is narrow. If the consolidated output reads like a generic linter, the personas are too broad — re-run `/reviewer:extract` or tighten the persona files by hand.
- This pairs with the `compound-engineering` plugin: the personas you extract slot into its `/workflows:review` parallel-agents list alongside (or instead of) the stock reviewers. See the plugin README.
