#!/usr/bin/env bash
# run-blind-review.sh — run the persona over blind hunks with the network OFF.
# Model-agnostic and cheat-proof: the reviewer sees code only and cannot reach
# GitHub, so it cannot fetch the real comments — whatever model it is.
#
# Usage:
#   REVIEW_CMD='claude -p' PERSONA=personas/alice.md \
#     ./run-blind-review.sh blind/api-1234.hunks.jsonl reviews/api-1234.review.jsonl
#
# REVIEW_CMD: any command that reads a prompt on STDIN and writes the review to
#   STDOUT. Examples:
#     claude:  REVIEW_CMD='claude -p --model claude-opus-4-8'
#     openai:  REVIEW_CMD='my-openai-cli --model gpt-5'   (your wrapper)
#     gemini:  REVIEW_CMD='gemini-cli generate'
#     local:   REVIEW_CMD='llama-cli -m model.gguf -p'
#
# The reviewer is sandboxed in two ways:
# - `unshare -rn` drops network access and verifies TCP egress is dead.
# - `bwrap` gives the command a filesystem view containing only /work plus
#   read-only system directories, so truth files elsewhere on the host cannot be
#   reached by relative or absolute path.
#
# If these primitives are unavailable, run this whole step inside an external
# no-network, filesystem-isolated sandbox and set EVAL_SANDBOXED=1 and
# EVAL_FS_SANDBOXED=1. Do NOT fall back to a normal host run.

set -euo pipefail

HUNKS="${1:?usage: run-blind-review.sh <blind-hunks.jsonl> <out-reviews.jsonl>}"
OUT="${2:?usage: run-blind-review.sh <blind-hunks.jsonl> <out-reviews.jsonl>}"
PERSONA="${PERSONA:?set PERSONA=path/to/persona.md}"
: "${REVIEW_CMD:?set REVIEW_CMD to a model that reads stdin and writes stdout}"

# ── Truth isolation (fail CLOSED) ───────────────────────────────────────────
# The reviewer must not be able to read the real comments. Two enforcements:
#
# (1) The blind input must contain ONLY code — no comment bodies. The file is
#     JSONL (one object per line); slurp ALL records and abort if ANY of them
#     carries a body/comment field (the ground truth). Checking only the first
#     record is not enough.
contaminated="$(jq -s 'any(.[]; type=="object" and (has("body") or has("comment")))' "$HUNKS" 2>/dev/null || echo error)"
if [[ "$contaminated" != "false" ]]; then
  if [[ "$contaminated" == "true" ]]; then
    echo "run-blind-review: blind input $HUNKS contains a body/comment field — that is the ground truth. Refusing (fail closed)." >&2
  else
    echo "run-blind-review: could not verify blind input $HUNKS is body-free (parse error). Refusing (fail closed)." >&2
  fi
  exit 70
fi
#
# (2) The review runs in an isolated workdir that holds ONLY the blind hunks and
#     the persona. The model is invoked from a mount namespace where this workdir
#     is the only writable/project data path, so no truth file elsewhere on the
#     host is reachable by relative or absolute path.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/blindreview.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cp "$PERSONA" "$WORK/persona.md"
cp "$HUNKS"   "$WORK/hunks.jsonl"
# Defence in depth: nothing truth-shaped may exist in the isolated workdir.
if compgen -G "$WORK/*truth*" >/dev/null 2>&1; then
  echo "run-blind-review: truth-shaped file in the isolated workdir. Aborting (fail closed)." >&2
  exit 70
fi

persona_text="$(cat "$WORK/persona.md")"

# egress_blocked — true only if a real TCP connect to the internet FAILS.
# Name resolution (getent/hosts) is NOT a valid probe: it reads /etc/hosts and
# cached resolvers even with no network. We probe actual TCP egress.
egress_blocked() {
  ! timeout 4 bash -c 'cat </dev/null >/dev/tcp/1.1.1.1/443' 2>/dev/null \
    && ! timeout 4 bash -c 'cat </dev/null >/dev/tcp/140.82.112.3/443' 2>/dev/null
}

# sandboxed CMD... — run CMD with network and filesystem isolation. Fails CLOSED
# unless it can enforce both, or the caller explicitly asserts an external
# sandbox with both EVAL_SANDBOXED=1 and EVAL_FS_SANDBOXED=1.
sandboxed() {
  if command -v bwrap >/dev/null 2>&1 && unshare -rn true 2>/dev/null; then
    bwrap_args=(
      --die-with-parent
      --new-session
      --proc /proc
      --dev /dev
      --tmpfs /tmp
    )
    for dir in /usr /bin /lib /lib64 /etc; do
      if [[ -e "$dir" ]]; then
        bwrap_args+=(--ro-bind "$dir" "$dir")
      fi
    done
    bwrap_args+=(--bind "$WORK" /work --chdir /work)

    # Verify egress inside the same network namespace, then enter the mount
    # namespace. The sandbox exposes no host /tmp, /home, repo checkout, or truth
    # directory; only /work and read-only system paths are visible.
    unshare -rn bwrap "${bwrap_args[@]}" /usr/bin/bash -c '
      if timeout 4 bash -c "cat </dev/null >/dev/tcp/1.1.1.1/443" 2>/dev/null \
         || timeout 4 bash -c "cat </dev/null >/dev/tcp/140.82.112.3/443" 2>/dev/null; then
        echo "run-blind-review: TCP egress reachable inside unshare -rn — sandbox not isolating. Aborting (fail closed)." >&2
        exit 70
      fi
      exec "$@"
    ' _ "$@"
  elif [[ -n "${EVAL_SANDBOXED:-}" && -n "${EVAL_FS_SANDBOXED:-}" ]]; then
    # Caller asserts this process is already inside a no-network + filesystem-
    # isolated sandbox. We can verify egress, but filesystem isolation is a trust
    # contract with the external sandbox.
    if egress_blocked; then
      (cd "$WORK" && "$@")
    else
      echo "run-blind-review: EVAL_SANDBOXED=1 set but TCP egress still works. Not cheat-proof. Aborting." >&2
      exit 70
    fi
  else
    echo "run-blind-review: cannot enforce network+filesystem isolation (requires unshare -rn + bwrap, or an external sandbox with EVAL_SANDBOXED=1 EVAL_FS_SANDBOXED=1). Aborting." >&2
    exit 70
  fi
}

: > "$OUT"
while IFS= read -r line; do
  id="$(jq -r '.id' <<<"$line")"
  path="$(jq -r '.path' <<<"$line")"
  hunk="$(jq -r '.diff_hunk' <<<"$line")"

  prompt="You are this code reviewer. Review ONLY the hunk below, in their voice and priorities. If they would comment, give the comment (terse, their style, concern + fix). If not, reply exactly: (clean).

=== PERSONA ===
${persona_text}

=== FILE: ${path} ===
${hunk}"

  # Run the model inside the sandbox: its filesystem world contains /work
  # (persona.md + hunks.jsonl) and read-only system paths, never the truth.
  # Preserve sandbox failures as fail-closed exits; only ordinary model-command
  # failures become per-hunk reviewer errors.
  set +e
  review="$(printf '%s' "$prompt" | sandboxed bash -c "$REVIEW_CMD")"
  review_status=$?
  set -e
  if [[ $review_status -eq 70 ]]; then
    exit 70
  elif [[ $review_status -ne 0 ]]; then
    review='(reviewer error)'
  fi
  jq -cn --argjson id "$id" --arg r "$review" '{id:$id, review:$r}' >> "$OUT"
done < "$HUNKS"

echo "Wrote $OUT ($(wc -l < "$OUT") reviews)." >&2
