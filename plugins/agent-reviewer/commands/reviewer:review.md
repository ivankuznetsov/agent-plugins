# Review With the Persona Panel

Review a diff or PR with your extracted reviewer personas, run as a panel — each persona commenting in their own voice and priorities, then consolidated.

## Usage

```text
/reviewer:review                       # review the current diff / uncommitted changes
/reviewer:review <file-or-PR>          # review a specific file, or an open PR
/reviewer:review --only <login>        # run a single persona instead of the whole panel
/reviewer:review --min-confidence 0.7  # raise the confidence gate (default 0.5)
```

## Prerequisites

- Personas extracted into `personas/*.md` (run `/reviewer:extract` first). If none exist, say so and point at `/reviewer:extract`.

## Behaviour

1. **Resolve what to review — with the repo, not just the diff.** An explicit argument wins. Otherwise: an open PR for the branch, else the current `git diff`, else uncommitted changes. If nothing's there, ask. Review **with the repository checked out** and hand each persona the whole change as context, not isolated hunks — the largest recall lever we measured was repo access (the persona grepping for the existing helper, the sibling test, the convention) plus whole-change context, far more than any prompt wording. For a large PR, walk it hunk-by-hunk *with the rest of the PR and the repo available*, rather than one shallow pass.
2. **Find the panel.** List `personas/*.md`. With `--only <login>`, use just that one.
3. **Pick a mode — integrate or standalone.** Check whether the `ce-code-review` skill (compound-engineering plugin) is installed.
   - **Integrated (preferred when present).** The extracted personas are *additional reviewers* on ce-code-review's panel, not a separate pass. Invoke ce-code-review for the same scope and add one `persona-reviewer` agent per persona to its dispatched set. Because `persona-reviewer` emits the shared finding schema (`references/finding-schema.md`), ce-code-review's existing merge/dedup/severity pipeline consumes our findings unchanged — the user gets **one** report combining its generic reviewers (correctness, security, …) with your team's specific voices. Don't run a second, parallel review.
   - **Standalone (when ce-code-review is absent).** Run the panel yourself (next step) and do the merge here.
4. **Run the panel in parallel.** Dispatch one `persona-reviewer` subagent per persona:

   ```text
   Task persona-reviewer("Persona: personas/<login>.md. Review: <what>.")
   ```

   Each returns a JSON array of findings (`references/finding-schema.md`).
5. **Gate, merge, and report** (standalone mode — in integrated mode ce-code-review does this).
   - **Confidence gate.** Drop findings whose `confidence` is below the threshold (default **0.5**, override with `--min-confidence`). This removes only what the persona itself was unsure about. Validated on held-out PRs: a 0.5 gate cut false positives with **no** recall loss (F1 up); higher thresholds trade recall for precision on a smooth curve. This is per-finding gating, not a blanket "be cautious" instruction — the persona still raises everything; the gate filters.
   - **Merge / dedupe.** Collapse findings that share file+line+concern, listing every persona who raised it — agreement across personas is a strong signal.
   - **Report.** Order by severity (critical → important → nit) and render each with the persona who raised it and their `comment` / `suggested_fix`. Keep distinct voices distinct; never flatten the panel into a generic review.

## Notes

- A panel works because each persona is narrow. If the consolidated output reads like a generic linter, the personas are too broad — re-run `/reviewer:extract` or tighten the persona files by hand.
- The shared finding schema is what makes integration free: install ce-code-review and your cloned reviewers join its panel automatically; skip it and this command is a complete standalone review skill. Either way the personas emit identical findings.
