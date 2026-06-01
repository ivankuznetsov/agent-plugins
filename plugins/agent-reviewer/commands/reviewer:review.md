# Review With the Persona Panel

Review a diff or PR with your extracted reviewer personas, run as a panel — each persona commenting in their own voice and priorities, then consolidated.

## Usage

```text
/reviewer:review                  # review the current diff / uncommitted changes
/reviewer:review <file-or-PR>     # review a specific file, or an open PR
/reviewer:review --only <login>   # run a single persona instead of the whole panel
```

## Prerequisites

- Personas extracted into `personas/*.md` (run `/reviewer:extract` first). If none exist, say so and point at `/reviewer:extract`.

## Behaviour

1. **Resolve what to review.** An explicit argument wins. Otherwise: an open PR for the branch, else the current `git diff`, else uncommitted changes. If nothing's there, ask.
2. **Find the panel.** List `personas/*.md`. With `--only <login>`, use just that one.
3. **Run the panel in parallel.** Dispatch one `persona-reviewer` subagent per persona:

   ```text
   Task persona-reviewer("Persona: personas/<login>.md. Review: <what>.")
   ```

4. **Consolidate.** Merge the panel's findings into one report, grouped by severity (🔴 Critical / 🟡 Important / 🔵 Nice-to-have), each finding tagged with the persona who raised it. Where two personas flag the same line, note the agreement — that's a strong signal. Keep distinct voices distinct; don't flatten them into a generic review.

## Notes

- A panel works because each persona is narrow. If the consolidated output reads like a generic linter, the personas are too broad — re-run `/reviewer:extract` or tighten the persona files by hand.
- This pairs with the `compound-engineering` plugin: the personas you extract slot into its `/workflows:review` parallel-agents list alongside (or instead of) the stock reviewers. See the plugin README.
