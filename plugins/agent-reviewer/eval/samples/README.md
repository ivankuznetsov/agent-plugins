# Public persona eval samples

A small, reproducible benchmark for the [cheat-proof persona eval](../README.md), built
from the **public** GitHub review history of four well-known, opinionated open-source
reviewers across three ecosystems. Use it to sanity-check the eval harness, to compare
reviewer models, or as a worked example of the data shape `/reviewer:extract` and
`run-eval.sh` expect — without needing access to a private team's PRs.

## The personas

| Directory | Reviewer | Repo | Ecosystem | Voice |
|---|---|---|---|---|
| `rails-dhh/` | [@dhh](https://github.com/dhh) | rails/rails | Ruby | Terse, opinionated; clarity over cleverness, REST purity, naming, conceptual compression |
| `rails-rafaelfranca/` | [@rafaelfranca](https://github.com/rafaelfranca) | rails/rails | Ruby | Rails-core thoroughness; backwards compatibility, public API surface, framework consistency |
| `kubernetes-thockin/` | [@thockin](https://github.com/thockin) | kubernetes/kubernetes | Go | Meticulous systems/API-design review; validation, versioning, naming precision, long-term API evolution |
| `elixir-josevalim/` | [@josevalim](https://github.com/josevalim) | elixir-lang/elixir | Elixir | Pedagogical, language-design framing; clarity, performance, idiomatic functional style |

**DHH and Rafael França review the *same* repo.** That pair is the most useful part of the
set: a faithful extraction should separate each reviewer's *personal* standards from the
*Rails* conventions they share — so the two personas should come out distinct, not
identical. It's the cleanest test of whether the profiler captures a voice rather than a
codebase.

## Layout (per persona)

```
<repo>-<login>/
  manifest.json              # reviewer, repo, ecosystem, collection date, PR list + counts
  context-<login>.json       # every collected comment WITH its diff + PR title — the
                             #   extraction input (output of scripts/collect-context.sh)
  blind/<repo>-<pr>.hunks.jsonl  # {id, path, diff_hunk} — code only, no comment body.
                                 #   All the sandboxed reviewer ever sees.
  truth/<repo>-<pr>.jsonl        # {id, body} — the reviewer's real comment. JUDGE-ONLY.
```

`blind/` + `truth/` are the recall benchmark; `context-<login>.json` is the persona-extraction
input. Totals: **4 personas, 24 PRs, 188 ground-truth comments**, plus 378 contextual
comments for extraction.

## How to use it

**Run the recall eval against an extracted persona** (prep is already done — these PRs are
pre-split, so you can skip the privileged GitHub step and go straight to blind review + judge):

```bash
cd plugins/agent-reviewer/eval
for pr in 56404 56471 54693 53726 52789 52472; do
  REVIEW_CMD='claude -p' PERSONA=personas/dhh.md \
    ./run-blind-review.sh samples/rails-dhh/blind/rails-$pr.hunks.jsonl /tmp/dhh-$pr.review.jsonl
  JUDGE_CMD='claude -p' \
    ./run-judge.sh /tmp/dhh-$pr.review.jsonl samples/rails-dhh/truth/rails-$pr.jsonl /tmp/dhh-$pr.scores.jsonl
done
```

**Test the extractor end-to-end**: feed `context-<login>.json` to `/reviewer:extract`
(or the `reviewer-profiler` agent) to produce `personas/<login>.md`, then run the recall eval
above. Because two of the personas share a repo, you can also eyeball whether the extractor
produced two genuinely different DHH/Rafael voices.

## How it was generated (reproducible)

```bash
# context (extraction input), per reviewer:
ORG=rails REPOS=rails SINCE=2024-01-01 LIMIT=40 \
  OUT=samples/rails-dhh/context-dhh.json \
  scripts/collect-context.sh dhh

# blind/truth bundle, per selected PR:
ORG=rails REPO=rails PR=56404 REVIEWER=dhh OUTDIR=samples/rails-dhh \
  eval/prep-blind-eval.sh
```

PRs were chosen as the reviewer's recent merged PRs carrying the most inline comments, so the
ground truth is substantive rather than rubber-stamp approvals. See each `manifest.json` for
the exact PR list and per-PR comment counts.

## Honest caveats

- **Conversational comments are in the truth files.** Some captured comments are replies or
  logistics ("opening another PR for that") rather than review judgments. That's deliberate —
  filtering "substantive vs. not" is the **judge's** job (`run-judge.sh`), and the recall metric
  is over substantive ground-truth comments only. Don't pre-filter the truth by hand.
- **Per-hunk review undercounts cross-file concerns.** See the [Known limits](../README.md#known-limits-read-before-trusting-a-number)
  in the eval README — give the reviewer the whole sanitized PR diff as context for a fairer number.
- **Snapshot in time.** Comments were collected on the date in each `manifest.json`; the eval
  scores each comment against its own captured `diff_hunk`, so re-collection isn't needed to
  reproduce a score.

## Provenance & licensing

Every comment here is a **public** GitHub pull-request review comment, reproduced with
attribution to its author and PR (see `manifest.json` and the `id`s, which map to the original
PR's comment order). This mirrors how public code-review datasets (e.g. SWE-bench) redistribute
public GitHub data. The comments remain the work of their authors; this directory is a
derivative collection for evaluation only. If you are one of these reviewers and want your data
removed, open an issue.
