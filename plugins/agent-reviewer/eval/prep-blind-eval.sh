#!/usr/bin/env bash
# prep-blind-eval.sh — build a CHEAT-PROOF eval bundle for one PR.
#
# Splits a reviewer's real comments into two files that live in different
# trust zones:
#   blind/<repo>-<pr>.hunks.jsonl  — {id, path, diff_hunk} ONLY. Code, no
#                                    comment text, no PR/repo/author. This is
#                                    all the (sandboxed) reviewer ever sees.
#   truth/<repo>-<pr>.jsonl        — {id, body} the reviewer's real comment.
#                                    JUDGE-ONLY. Must never enter the sandbox.
#
# A reviewer holding only the blind file cannot recover the truth even with
# full internet, because nothing in it identifies the PR.
#
# Usage:
#   ORG=acme REPO=api PR=1234 REVIEWER=alice ./prep-blind-eval.sh
#
# Requires: gh (authenticated), jq.  (This is the PRIVILEGED step — it is the
# only part that touches GitHub. Run it once; everything downstream is offline.)

set -euo pipefail

ORG="${ORG:?set ORG}"; REPO="${REPO:?set REPO}"; PR="${PR:?set PR}"; REVIEWER="${REVIEWER:?set REVIEWER}"
OUTDIR="${OUTDIR:-.}"

# Validate operator-supplied identifiers before they reach gh/jq.
[[ "$ORG" =~ ^[A-Za-z0-9._-]+$ ]]    || { echo "invalid ORG: $ORG" >&2; exit 64; }
[[ "$REPO" =~ ^[A-Za-z0-9._-]+$ ]]   || { echo "invalid REPO: $REPO" >&2; exit 64; }
[[ "$PR" =~ ^[0-9]+$ ]]              || { echo "invalid PR (must be a number): $PR" >&2; exit 64; }
[[ "$REVIEWER" =~ ^[A-Za-z0-9-]+$ ]] || { echo "invalid REVIEWER: $REVIEWER" >&2; exit 64; }

mkdir -p "$OUTDIR/blind" "$OUTDIR/truth"

# Reviewer login passed as jq --arg (injection-safe), not interpolated into the filter.
raw="$(gh api "repos/$ORG/$REPO/pulls/$PR/comments" --paginate 2>/dev/null \
  | jq -s --arg rev "$REVIEWER" '[.[][] | select(.user.login==$rev) | {body:.body, path:.path, diff_hunk:.diff_hunk}] | to_entries | map({id:.key} + .value)')"

# Blind: code only. Strip body. (path + diff_hunk are code context, not the
# reviewer's verdict — they reveal nothing about what the reviewer said.)
echo "$raw" | jq -c '.[] | {id, path, diff_hunk}' > "$OUTDIR/blind/${REPO}-${PR}.hunks.jsonl"

# Truth: the reviewer's actual words, held separately for the judge.
echo "$raw" | jq -c '.[] | {id, body}' > "$OUTDIR/truth/${REPO}-${PR}.jsonl"

n="$(echo "$raw" | jq 'length')"
echo "Wrote $OUTDIR/blind/${REPO}-${PR}.hunks.jsonl and $OUTDIR/truth/${REPO}-${PR}.jsonl ($n comments)." >&2
echo "Reminder: keep truth/ out of the review sandbox." >&2
