# Judge prompt (per-comment scoring)

The judge is the grader — it legitimately sees the ground truth. It must be a
SEPARATE invocation from the reviewer, run after the review is frozen, ideally
on a DIFFERENT model than the reviewer (to avoid shared blind spots).

Inputs per PR:
- `reviews/<repo>-<pr>.review.jsonl` — `{id, review}` the persona's frozen verdict per hunk.
- `truth/<repo>-<pr>.jsonl` — `{id, body}` the reviewer's real comment per hunk.

Prompt:

> You are an independent, adversarial eval judge. For each `id`, you are given
> the persona's blind review verdict for a code hunk and the real reviewer's
> actual comment on that same hunk. Decide whether the persona independently
> raised the real reviewer's point.
>
> For each id:
> 1. Classify the real comment as **chatter** (not a substantive review point —
>    "ok", "done", "+", a bare acknowledgment) → exclude from the denominator,
>    or **substantive**.
> 2. For substantive comments: **MATCH** only if the persona's verdict raises
>    substantively the SAME concern about the SAME code — not merely "both
>    mention this hunk", and not "same hunk, different concern". Be strict; when
>    in doubt, it is not a match.
>
> Output: a table of id | substantive? | match? | one-line justification, then:
> - N_substantive, M (matches)
> - **Recall = M / N_substantive**
> - the classes of comment matched vs missed.

Aggregate recall across PRs is the headline metric. Report it per persona
version so you can see iterations improve (or regress).

## Notes
- The match rule is deliberately strict: a persona that flags the right line
  for its own pet reason should NOT score — that is the "right hunk, wrong
  concern" failure, and counting it would hide a real weakness.
- Run the judge on a different model than the reviewer when possible. If you
  must reuse the model, that is acceptable for the judge (it has the truth and
  is only grading) — the cheat-proofing constraint is on the *reviewer*, not the
  judge.
