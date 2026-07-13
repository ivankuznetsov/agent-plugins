# Finding schema (ce-code-review compatible)

The shared contract for a single review finding. It is deliberately a **superset-compatible
subset** of the [`ce-code-review`](https://github.com/EveryInc/compound-engineering-plugin)
finding envelope, so that an extracted persona can be dropped into ce-code-review's panel and
its merge/dedup stage consumes our findings unchanged — while the same schema also drives our
own standalone report when ce-code-review isn't installed.

One finding = one JSON object:

```json
{
  "reviewer": "<persona login>",        // who raised it — keeps panel output attributed
  "file": "path/to/file.rb",
  "line": 42,                            // best-effort; null if not line-specific
  "severity": "critical | important | nit",
  "confidence": 0.0,                     // 0–1: how sure THIS persona is they'd raise it
  "title": "<≤8-word summary>",
  "comment": "<the finding in the persona's own voice, terse>",
  "why_it_matters": "<the persona's reasoning, not generic best-practice boilerplate>",
  "suggested_fix": "<concrete fix, or null>",
  "pre_existing": false,                 // true if the issue predates this diff
  "requires_verification": false         // true if the persona is guessing and a human should check
}
```

Field notes:
- `severity` maps to ce-code-review's P0–P3 ladder: `critical`→P0/P1, `important`→P2, `nit`→P3.
- `confidence` is per-finding (not a blanket "be cautious" — see the persona-reviewer's calibration).
  A consumer may gate on it (e.g. drop `confidence < 0.5`); the reviewer still *emits* the finding.
- `pre_existing` / `requires_verification` are advisory flags a real reviewer applies implicitly.
- `suggested_fix` is null when the persona would not hand over a fix.
- ce-code-review-only fields (`autofix_class`, `owner`) are optional; when absent, ce-code-review
  defaults them. We do not invent them — a cloned human reviewer doesn't think in autofix classes.

Output is a JSON array of these objects. If the change is clean by the persona's standards,
return `[]` (an empty array) — not a fabricated finding.
