#!/usr/bin/env bash
# collect-context.sh — collect ONE reviewer's review CONTEXT, not just their comments.
#
# A reviewer's standards don't live in the comment; they live in the gap between
# what the code did and what the reviewer wanted. So for every inline comment we
# keep the diff it was left on and the PR's intent. That context is what makes a
# persona legible to the profiler agent.
#
# Usage:
#   ORG=your-org REPOS="repo1 repo2" SINCE=2025-01-01 ./collect-context.sh <reviewer-login>
#
# Output: context-<reviewer>.json  (a JSON array of contextual comments)
#
# Requires: gh (authenticated), jq.
# Note: this is the SHAPE of what you need, not gospel. Adjust the gh queries to
# how your org actually tags reviews. Claude will happily extend it (e.g. to pull
# full reply threads via in_reply_to, or PR bodies as well as titles).

set -euo pipefail

REVIEWER="${1:?usage: ORG=your-org REPOS=\"repo1 repo2\" $0 <reviewer-login>}"
ORG="${ORG:?set ORG=your-org}"
SINCE="${SINCE:-2025-01-01}"
# gh pr list defaults to 30 results — far too few for a real review history.
# Pull the whole window; override with LIMIT if a repo has more merged PRs.
LIMIT="${LIMIT:-2000}"
OUT="${OUT:-context-${REVIEWER}.json}"

if [[ -z "${REPOS:-}" ]]; then
  echo "set REPOS=\"repo1 repo2 ...\"" >&2
  exit 64
fi
read -r -a REPO_LIST <<< "${REPOS}"

# Validate operator-supplied identifiers before they reach gh/jq (defence in depth).
[[ "${ORG}" =~ ^[A-Za-z0-9._-]+$ ]]      || { echo "invalid ORG: ${ORG}" >&2; exit 64; }
[[ "${REVIEWER}" =~ ^[A-Za-z0-9-]+$ ]]   || { echo "invalid REVIEWER: ${REVIEWER}" >&2; exit 64; }
for r in "${REPO_LIST[@]}"; do
  [[ "$r" =~ ^[A-Za-z0-9._-]+$ ]]        || { echo "invalid repo name: ${r}" >&2; exit 64; }
done

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

for REPO in "${REPO_LIST[@]}"; do
  echo "Scanning ${ORG}/${REPO} for reviews by ${REVIEWER}…" >&2
  # Capture PR numbers with explicit failure handling, so a repo/API/auth hiccup
  # skips that repo with a warning instead of aborting collection under set -e.
  prs="$(gh pr list -R "${ORG}/${REPO}" --state merged --limit "${LIMIT}" \
      --search "merged:>${SINCE} reviewed-by:${REVIEWER}" \
      --json number -q '.[].number' 2>/dev/null)" || {
    echo "  warning: could not list PRs for ${ORG}/${REPO} (skipping this repo)." >&2
    continue
  }
  for PR in $prs; do

    # The PR's intent — what was this change trying to do?
    TITLE="$(gh pr view "${PR}" -R "${ORG}/${REPO}" --json title -q '.title' 2>/dev/null || echo '')"

    # Inline comments by this reviewer, WITH the diff they were left on and a
    # pointer to the thread they belong to. All operator/data values go through
    # jq --arg/--argjson, so none can break out of the filter (injection-safe).
    # (gh --paginate emits a stream of page arrays; `jq '.[]'` handles that.)
    gh api "repos/${ORG}/${REPO}/pulls/${PR}/comments" --paginate 2>/dev/null \
      | jq -c --arg rev "${REVIEWER}" --arg repo "${REPO}" \
             --arg title "${TITLE}" --argjson pr "${PR}" '
          .[] | select(.user.login==$rev) |
          {pr:$pr, repo:$repo, title:$title,
           path:.path, diff_hunk:.diff_hunk, body:.body,
           in_reply_to:.in_reply_to_id}' >> "${TMP}" || true
  done
done

jq -s '.' "${TMP}" > "${OUT}"
echo "Wrote ${OUT} ($(jq 'length' "${OUT}") comments)." >&2
