# Full Cycle Command

Run the whole pipeline on a topic: journalist gathers and verifies the brief, then the writer and editor enter a continuous write↔edit cycle until the editor's verdict is `ready` or the configured maximum number of rounds is reached. The cycle is the point. Cooperation creates sycophancy, so the writer and editor are deliberately set up as rivals — the writer pushes toward output, the editor pulls toward quality, and the loop runs until either the editor releases the draft or the cap stops it.

All artifacts land in the user's project working directory under `./writing/`, not inside the plugin.

## Usage

```text
/write:full <topic> [--scope <path>] [--max-rounds <N>]
```

## Arguments

- **`<topic>`** *(required)* — the question or subject to investigate and draft. Same shape as `/write:journalist`.
- **`--scope <path>`** *(optional)* — restrict the journalist's local search to this directory. Defaults to the repository root.
- **`--max-rounds <N>`** *(optional)* — maximum number of writer↔editor rounds before the cycle stops. Defaults to **5**. Each round is one writer pass + one editor pass. The cap is a safety belt; the normal exit is the editor's `ready` verdict.

## Behavior

This command does not re-encode any voice. It sequences the existing subagents and threads their outputs.

### Step 1 — Investigate (and verify)

Dispatch `agent-writing:journalist` on the topic. The journalist files the brief at `./writing/investigations/<slug>-<date>.md` (where the slug is derived from the topic) and runs the source-verification post-step before the brief is final. The brief's frontmatter carries `verification: passed` or `verification: partial`; either is acceptable for entering the cycle, but the writer should be alerted when claims are flagged `[unverified]` in the body.

**If the journalist files an "I couldn't ground this" note** (because the evidence was thin), the orchestrator stops here. Running the writer against an empty brief produces fabrication. The final response surfaces the journalist's honest note and stops the cycle. There is no failure here — the journalist did the right thing, and the user now knows what to investigate further before drafting.

### Step 2 — Enter the cycle

Otherwise, the orchestrator enters the writer↔editor loop. Round counter `N` starts at 1.

**Round `N`:**

1. Dispatch `agent-writing:writer`.
   - On round 1: the writer gets the brief and produces the first draft at `./writing/drafts/<slug>-<date>-v1.md`.
   - On round `N` > 1: the writer gets the brief AND the prior review (`./writing/reviews/<slug>-<date>-v<N-1>.md`) via `--review`, and rewrites — saving `./writing/drafts/<slug>-<date>-v<N>.md`.
2. Dispatch `agent-writing:editor` on the draft just produced. The editor reads the draft as an adversary and files `./writing/reviews/<slug>-<date>-v<N>.md` with a `verdict:` in the frontmatter.
3. Read the verdict.
   - **`ready`** → exit the cycle. Go to Step 3.
   - **`needs another pass`** → increment `N`. If `N` exceeds `--max-rounds`, exit the cycle with the cap-hit note (Step 3 covers this). Otherwise, run round `N` again.
   - **`start over`** → increment `N`. On the next round, the writer's invocation includes an explicit instruction to ignore the prior draft and write a fresh draft from the brief. The prior review is still passed so the writer can avoid the angle that failed. Then continue as usual.
   - Any other value (defensive): log the unexpected verdict and treat as `needs another pass`.

### Step 3 — Emit the summary

Emit a final response that includes:

- The topic.
- The brief path.
- The final draft path.
- The final review path.
- The number of rounds run.
- The final verdict.

If the cycle exited because the cap was hit (final verdict was not `ready`), the response also includes a "cycle hit the cap" note so the user can decide whether to keep iterating manually by invoking `/write:writer --review` and `/write:editor` directly.

## Why the cycle lives in the orchestrator

The writer and the editor must not invoke each other from inside their own reasoning. The writer can't call its own critic, and the editor can't pre-soften because it does not know whether the writer will rewrite. The orchestrator owns the loop — it is the only thing that knows what round it is, what the prior review said, and when to stop. This separation is what preserves the rivalry. If the writer ever started calling the editor inline, the model would optimize for the next round of feedback rather than for the draft, and the writing would collapse back into the "cooperation creates sycophancy" failure mode the plugin is designed to prevent.

## Output

Three sets of files in the user's project working directory, all sharing a slug and date derived from the topic:

```
./writing/investigations/<slug>-<date>.md      # the journalist's brief (with Verification section)
./writing/drafts/<slug>-<date>-v1.md           # writer round 1
./writing/reviews/<slug>-<date>-v1.md          # editor round 1
./writing/drafts/<slug>-<date>-v2.md           # writer round 2 (if needed)
./writing/reviews/<slug>-<date>-v2.md          # editor round 2 (if needed)
…
```

The `./writing/` tree is created on demand if it doesn't exist. The user can add `/writing/` to their project's `.gitignore` if they don't want artifacts versioned.

And a final response naming the brief, the final draft, the final review, the round count, and the final verdict.

## Examples

### Converges on round 1

```
$ /write:full "the screenote plugin's annotation flow"

Filed brief: ./writing/investigations/screenote-annotation-flow-2026-05-26.md
  Verification: passed (12 of 12 sources verified)
Round 1:
  Draft  → ./writing/drafts/screenote-annotation-flow-2026-05-26-v1.md
  Review → ./writing/reviews/screenote-annotation-flow-2026-05-26-v1.md
  Verdict: ready

Done after 1 round.
```

### Takes three rounds

```
$ /write:full "what changed in agent-seo between v0.9 and v1.1"

Filed brief: ./writing/investigations/agent-seo-v09-to-v11-2026-05-26.md
  Verification: partial (8 of 10 sources verified; 2 inline-flagged [unverified])
Round 1: verdict needs another pass
Round 2: verdict needs another pass
Round 3:
  Draft  → ./writing/drafts/agent-seo-v09-to-v11-2026-05-26-v3.md
  Review → ./writing/reviews/agent-seo-v09-to-v11-2026-05-26-v3.md
  Verdict: ready

Done after 3 rounds.
```

### Hits the cap

```
$ /write:full "the philosophy of test-driven development" --max-rounds 5

Filed brief: ./writing/investigations/philosophy-of-tdd-2026-05-26.md
  Verification: passed
Round 1: verdict needs another pass
Round 2: verdict needs another pass
…
Round 5: verdict needs another pass

Cycle hit the cap (5 rounds) without the editor returning ready.
Final draft:  ./writing/drafts/philosophy-of-tdd-2026-05-26-v5.md
Final review: ./writing/reviews/philosophy-of-tdd-2026-05-26-v5.md

You can keep iterating manually:
  /write:writer ./writing/drafts/philosophy-of-tdd-2026-05-26-v5.md --review ./writing/reviews/philosophy-of-tdd-2026-05-26-v5.md
  /write:editor ./writing/drafts/philosophy-of-tdd-2026-05-26-v6.md
```

### Journalist can't ground the topic

```
$ /write:full "the spaceflight history of the agent-plugins repo"

Filed "couldn't ground this" note: ./writing/investigations/spaceflight-history-2026-05-26.md
Cycle stopped at the journalist — there was no grounded brief to draft from.

./writing/investigations/spaceflight-history-2026-05-26.md names what was searched and
what would need to be true to file a real brief.
```
