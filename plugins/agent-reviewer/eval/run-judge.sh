#!/usr/bin/env bash
# run-judge.sh — score a frozen blind review against the real reviewer's
# comments, per comment. Model-agnostic. The judge is the grader: it legitimately
# sees the truth, runs AFTER the review is frozen, and should use a DIFFERENT
# model than the reviewer when possible.
#
# Usage:
#   JUDGE_CMD='claude -p' \
#     ./run-judge.sh reviews/api-1234.review.jsonl truth/api-1234.jsonl scores/api-1234.jsonl
#
# JUDGE_CMD: any model reading a prompt on STDIN, writing to STDOUT. The judge
# may have network — it is not cheat-constrained (only the reviewer is).
#
# Match rule (strict): a real comment counts as matched only if the persona's
# verdict raised substantively the SAME concern about the SAME code — not "same
# hunk, different concern".
#
# Requires: jq.

set -euo pipefail

REVIEWS="${1:?usage: run-judge.sh <reviews.jsonl> <truth.jsonl> <out-scores.jsonl>}"
TRUTH="${2:?usage: run-judge.sh <reviews.jsonl> <truth.jsonl> <out-scores.jsonl>}"
OUT="${3:?usage: run-judge.sh <reviews.jsonl> <truth.jsonl> <out-scores.jsonl>}"
: "${JUDGE_CMD:?set JUDGE_CMD to a model that reads stdin and writes stdout}"

: > "$OUT"
# Iterate truth ids (the denominator is the real comments).
while IFS= read -r t; do
  id="$(jq -r '.id' <<<"$t")"
  body="$(jq -r '.body' <<<"$t")"
  # Slurp and take the first match in jq itself. Piping `jq | head -1` closes the
  # pipe early, jq takes SIGPIPE, and under `set -o pipefail` that aborts the run.
  review="$(jq -rs --argjson id "$id" 'map(select(.id==$id)) | (.[0].review // "")' "$REVIEWS")"
  if [[ -z "$review" ]]; then review="(no verdict for this id)"; fi

  prompt="You are a strict, adversarial code-review eval judge.

REAL REVIEWER'S COMMENT on a code hunk:
${body}

PERSONA'S BLIND VERDICT on the same hunk (it never saw the real comment):
${review}

Decide:
1. substantive: is the real comment a substantive review point (true) or chatter like ok/done/+/a bare ack (false)?
2. match: did the persona raise substantively the SAME concern about the SAME code? Not 'both mention this hunk'; not 'same hunk, different concern'. If in doubt, false.

Output ONLY one line of JSON, nothing else: {\"substantive\": true|false, \"match\": true|false}"

  # Per-comment scoring must never abort the loop. Tolerate model/parse errors.
  set +e
  raw="$(printf '%s' "$prompt" | bash -c "$JUDGE_CMD" 2>/dev/null)"
  verdict="$(grep -oE '\{[^{}]*\}' <<<"$raw" | tail -1)"
  [[ -z "$verdict" ]] && verdict='{}'
  sub="$(jq -r 'try (.substantive|tostring) catch "null"' <<<"$verdict" 2>/dev/null)"
  match="$(jq -r 'try (.match|tostring) catch "null"' <<<"$verdict" 2>/dev/null)"
  set -e
  [[ "$sub" == "true" || "$sub" == "false" ]] || sub="null"
  [[ "$match" == "true" ]] || match="false"
  jq -cn --argjson id "$id" --arg s "$sub" --arg m "$match" \
    '{id:$id, substantive:($s=="true"), match:($m=="true"), parsed:($s!="null")}' >> "$OUT"
done < "$TRUTH"

# Tally
n_sub="$(jq -s '[.[]|select(.substantive)]|length' "$OUT")"
m="$(jq -s '[.[]|select(.substantive and .match)]|length' "$OUT")"
unparsed="$(jq -s '[.[]|select(.parsed|not)]|length' "$OUT")"
recall="$(awk -v m="$m" -v n="$n_sub" 'BEGIN{printf (n>0)? "%.1f" : "n/a", (n>0)?100*m/n:0}')"
echo "scores: $OUT | substantive=$n_sub matched=$m recall=${recall}% (unparsed judge replies: $unparsed)" >&2
