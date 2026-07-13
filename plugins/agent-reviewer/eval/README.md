# Cheat-proof persona eval

How to measure whether an extracted persona actually reviews like the real person — in a way a model **cannot game**, and that works with **any** model (Claude, GPT, Gemini, local).

## Quickstart — eval your persona against your team's reviewer

After you've extracted a persona (`/reviewer:extract`), pick a handful of merged PRs that reviewer actually commented on, and run:

```bash
ORG=acme REPO=api REVIEWER=alice PRS="1201 1188 1175" \
PERSONA=personas/alice.md \
REVIEW_CMD='claude -p' \
JUDGE_CMD='claude -p' \
  ./run-eval.sh
```

It prints per-PR and aggregate **per-comment recall** — of Alice's real substantive comments, how many your persona independently raised. The reviewer step runs offline and sees only code, so the number is honest. Swap `REVIEW_CMD`/`JUDGE_CMD` for any model. Everything below is what `run-eval.sh` does under the hood, and why it can't be gamed.

## The question

Take real PRs the reviewer actually commented on. Strip their comments. Run the persona reviewer over the same code. Compare the persona's feedback to what the real reviewer said. The metric is **per-comment recall**: of the reviewer's real substantive comments, how many did the persona independently raise?

## Why "cheat-proof" matters

The ground truth (the reviewer's comments) lives in the PR on GitHub. If the reviewing model has network + `gh`, it can fetch those comments and parrot them back instead of actually reviewing — scoring ~100% while proving nothing. Instruction ("don't read the comments") is not enough, especially for models other than the one you tuned the prompt on. Cheating must be **impossible by construction**, not discouraged by request.

## The five guarantees

1. **Reviewer sees code only.** Input is the diff/hunks, sanitized: PR number, repo name, and author stripped, so a networked model can't even look the PR up.
2. **Reviewer runs with no network and no host filesystem.** The default sandbox composes `unshare -rn` (network off, verified by real TCP probes) with `bwrap` (mount namespace). It physically cannot reach GitHub or host files outside the sandbox, whatever the model "wants".
3. **Ground truth is unreachable during review.** `run-blind-review.sh` runs the model in a throwaway `/work` mount containing only the blind hunks and the persona; host `/tmp`, `/home`, the repo checkout, and `truth/` are not mounted. It **fails closed** (exit 70) if the blind input is contaminated with a comment body, if the file cannot be parsed, or if the script cannot enforce both network and filesystem isolation. Only the judge ever receives the truth file.
4. **Output is frozen before truth is introduced.** The reviewer writes its review; only then does the judge run.
5. **Model-agnostic.** The reviewer step is `model(persona + sanitized_hunk) → text`. Swap any model in. Integrity comes from the sandbox, not the model's goodwill.

## The harness

Three steps, three trust zones, wired together by `run-eval.sh`:

```
  PRIVILEGED prep            SANDBOXED review            PRIVILEGED judge
  (has gh + network)         (no network, code only)     (has truth)
  ────────────────           ──────────────────          ────────────────
  prep-blind-eval.sh   ─►    run-blind-review.sh   ─►    run-judge.sh (LLM)
    blind/<pr>.hunks.jsonl     reviews/<pr>.review.jsonl   scores/<pr>.jsonl
    truth/<pr>.jsonl  ──────────────────────────────────────────►┘
    (truth NEVER enters the sandbox)
```

`run-eval.sh` runs all three over a list of PRs and reports recall. The individual scripts are below if you want to run a single stage.

### 1. Prep (privileged — run once, offline thereafter)

```bash
ORG=<org> REPO=<repo> PR=<n> REVIEWER=<login> ./prep-blind-eval.sh
```

Writes two things to **separate** locations:
- `blind/<repo>-<pr>.hunks.jsonl` — one object per real comment: `{id, path, diff_hunk}`. **No comment body. No PR number. No repo. No author.** This is all the reviewer ever sees.
- `truth/<repo>-<pr>.jsonl` — `{id, body}` (the reviewer's real comment). **Judge-only. Never goes near the sandbox.**

A reviewer holding only `blind/…` cannot recover the truth even with full internet, because nothing in it identifies the PR.

### 2. Blind review (sandboxed — any model)

```bash
REVIEW_CMD='<your model invocation reading stdin → stdout>' \
PERSONA=personas/<login>.md \
  ./run-blind-review.sh blind/<repo>-<pr>.hunks.jsonl reviews/<repo>-<pr>.review.jsonl
```

For each hunk it composes `persona + "review this hunk"` and pipes it to `REVIEW_CMD`, run **with networking disabled** (`unshare -rn`, egress re-verified by a real TCP probe before each call) and **filesystem-isolated** (`bwrap`, exposing only `/work` with the persona + blind hunks plus read-only system directories). `REVIEW_CMD` is any model command available inside that sandbox:
- Claude: `claude -p --model …`
- OpenAI: a one-line `openai` / `curl` wrapper
- Gemini, local llama.cpp, etc.

It **fails closed**: if the blind input contains a comment body, if parsing fails, or if network + filesystem isolation cannot be enforced, it exits non-zero instead of running. If `bwrap`/`unshare` are unavailable, run this whole step in an externally verified no-network, filesystem-isolated sandbox and set both `EVAL_SANDBOXED=1` and `EVAL_FS_SANDBOXED=1`.

### 3. Judge (privileged — separate model invocation)

```bash
JUDGE_CMD='claude -p' \
  ./run-judge.sh reviews/<repo>-<pr>.review.jsonl truth/<repo>-<pr>.jsonl scores/<repo>-<pr>.jsonl
```

Per id, `run-judge.sh` feeds the model the **frozen** review verdict and the real comment and records `{substantive, match}`, then prints recall. The judge legitimately sees the truth — it is the grader, not the reviewer — so it may have network. Use a *different* model from the reviewer when you can, to avoid shared blind spots. The scoring prompt is in `judge-prompt.md`.

Match rule: a comment counts only if the persona raised **substantively the same concern at the same code** — not merely "said something about this hunk". Be adversarial.

**Recall = matched / substantive ground-truth comments.** Report per PR and aggregate. Track it across persona iterations; it is the only metric not confounded by which revision you happened to review.

## Known limits (read before trusting a number)

- **Per-hunk review undercounts cross-file concerns.** Feeding isolated hunks blinds the reviewer to "reuse the helper in the other file" / "one implementation across the PR". Our own runs: per-hunk ≈ 18% recall, whole-PR-context ≈ 29% on the same comments. For a fair number, give the reviewer the **whole sanitized PR diff** as context alongside the hunk under review (still no network, still no comment bodies).
- **Some comments are uncatchable from a diff at all** — "add a test for this", "this should live on the server", missing-feature asks. They need repo-wide context and reasoning about *absence*. Treat them as a separate bucket; don't expect a diff reviewer to hit them.
- **The reviewer's real comments span many PR revisions.** Score per-comment against each comment's own `diff_hunk` (which `prep-blind-eval.sh` captures), not against one static diff — a single snapshot only contains a slice of what they commented on.
