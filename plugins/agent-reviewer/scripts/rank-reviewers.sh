#!/usr/bin/env bash
# rank-reviewers.sh — find who actually does the reviews, and flag the ones
# whose contribution is significant enough to be worth their own persona.
#
# A repo often has more than one prominent reviewer. The skill uses this output
# to open a dialog: "I see N reviewers with significant volume — build a persona
# for each, or a subset?" So this script doesn't just count, it marks the natural
# cutoff (share of the top reviewer) and prints a suggestion.
#
# Usage:
#   ORG=your-org REPOS="repo1 repo2" ./rank-reviewers.sh
#   ./rank-reviewers.sh your-org repo1 repo2 repo3
#
# Tunables:
#   SIGNIF_PCT  reviewers with >= this % of the top reviewer's count are flagged
#               "significant" (default 25).
#   LIMIT       PRs scanned per repo (default 1000).
#
# Requires: gh (authenticated), jq.

set -euo pipefail

ORG="${ORG:-${1:-}}"
if [[ -z "${ORG}" ]]; then
  echo "usage: ORG=your-org REPOS=\"repo1 repo2\" $0   (or: $0 <org> <repo>...)" >&2
  exit 64
fi
shift || true

if [[ -n "${REPOS:-}" ]]; then
  read -r -a REPO_LIST <<< "${REPOS}"
else
  REPO_LIST=("$@")
fi
if [[ ${#REPO_LIST[@]} -eq 0 ]]; then
  echo "no repos given. Set REPOS=\"repo1 repo2\" or pass them as arguments." >&2
  exit 64
fi

LIMIT="${LIMIT:-1000}"
SIGNIF_PCT="${SIGNIF_PCT:-25}"

for REPO in "${REPO_LIST[@]}"; do
  gh pr list -R "${ORG}/${REPO}" --state merged --limit "${LIMIT}" --json reviews \
    -q '.[].reviews[].author.login' 2>/dev/null || true
done | sort | uniq -c | sort -rn | awk -v pct="${SIGNIF_PCT}" '
  BEGIN {
    printf "  %-22s %8s  %7s\n", "reviewer", "reviews", "of top"
    printf "  %-22s %8s  %7s\n", "----------------------", "-------", "-------"
  }
  NR == 1 { top = $1 }
  {
    rows++
    login = $2; count = $1
    share = (top > 0 ? (count / top) * 100 : 0)
    signif = (share >= pct)
    mark = (signif ? " ★" : "")
    printf "  %-22s %8d  %6.1f%%%s\n", login, count, share, mark
    if (signif) { sig[++n] = login }
  }
  END {
    print ""
    if (rows == 0) {
      print "No reviewers found. Check the org/repo names, gh auth, and that the repos have merged PRs with reviews."
    } else if (n <= 1) {
      print "Suggestion: one clearly dominant reviewer (★). Build a single persona."
    } else {
      printf "Suggestion: %d reviewers clear the significance bar (★, >= %d%% of the top):\n  ", n, pct
      for (i = 1; i <= n; i++) printf "%s%s", sig[i], (i < n ? ", " : "\n")
      print "Consider a persona for each and run them as a panel. Confirm the set with the user."
    }
  }
'
