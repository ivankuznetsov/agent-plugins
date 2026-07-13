#!/usr/bin/env bash
# run-eval.sh — one-command, cheat-proof, model-agnostic persona eval.
# Chains prep (privileged) → blind review (sandboxed, no network) → judge,
# over a list of PRs, and prints per-PR and aggregate per-comment recall.
#
# Eval YOUR persona against YOUR team's real reviewer:
#
#   ORG=acme REPO=api REVIEWER=alice PRS="1201 1188 1175" \
#   PERSONA=personas/alice.md \
#   REVIEW_CMD='claude -p' \
#   JUDGE_CMD='claude -p' \
#     ./run-eval.sh
#
# REVIEW_CMD / JUDGE_CMD: any model that reads a prompt on stdin → text on
# stdout (claude, an openai/gemini wrapper, a local model). Use a different
# model for the judge than the reviewer when you can.
#
# Cheat-proof: the reviewer only ever sees code (no comment bodies, no PR/repo
# identifiers) and runs with the network provably off (see run-blind-review.sh).
# The truth never enters the review step.
#
# Requires: gh (for prep only), jq, and a sandbox primitive (unshare -rn) or a
# no-network container for the review step.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

ORG="${ORG:?set ORG}"; REPO="${REPO:?set REPO}"; REVIEWER="${REVIEWER:?set REVIEWER}"
PRS="${PRS:?set PRS=\"123 124 125\"}"; PERSONA="${PERSONA:?set PERSONA=path/to/persona.md}"
: "${REVIEW_CMD:?set REVIEW_CMD}"; : "${JUDGE_CMD:?set JUDGE_CMD}"
OUTDIR="${OUTDIR:-eval-run}"
mkdir -p "$OUTDIR"/{blind,truth,reviews,scores}

tot_sub=0; tot_m=0
for PR in $PRS; do
  echo "=== $REPO #$PR ===" >&2
  # 1. prep (privileged — touches GitHub once)
  ORG="$ORG" REPO="$REPO" PR="$PR" REVIEWER="$REVIEWER" OUTDIR="$OUTDIR" \
    "$HERE/prep-blind-eval.sh"
  # 2. blind review (sandboxed, no network, code only)
  PERSONA="$PERSONA" REVIEW_CMD="$REVIEW_CMD" \
    "$HERE/run-blind-review.sh" "$OUTDIR/blind/${REPO}-${PR}.hunks.jsonl" "$OUTDIR/reviews/${REPO}-${PR}.review.jsonl"
  # 3. judge (has truth; separate model ideally)
  JUDGE_CMD="$JUDGE_CMD" \
    "$HERE/run-judge.sh" "$OUTDIR/reviews/${REPO}-${PR}.review.jsonl" "$OUTDIR/truth/${REPO}-${PR}.jsonl" "$OUTDIR/scores/${REPO}-${PR}.jsonl"
  s="$(jq -s '[.[]|select(.substantive)]|length' "$OUTDIR/scores/${REPO}-${PR}.jsonl")"
  m="$(jq -s '[.[]|select(.substantive and .match)]|length' "$OUTDIR/scores/${REPO}-${PR}.jsonl")"
  tot_sub=$((tot_sub+s)); tot_m=$((tot_m+m))
  awk -v r="$REPO" -v p="$PR" -v m="$m" -v s="$s" 'BEGIN{printf "  %s #%s: %d/%d = %s%%\n", r, p, m, s, (s>0)?sprintf("%.0f",100*m/s):"n/a"}' >&2
done

echo "=== AGGREGATE recall: ${tot_m}/${tot_sub} = $(awk -v m="$tot_m" -v s="$tot_sub" 'BEGIN{printf (s>0)?"%.1f":"n/a",(s>0)?100*m/s:0}')% ===" >&2
