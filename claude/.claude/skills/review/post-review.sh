#!/usr/bin/env bash
# post-review.sh
# Reads the council review from the Obsidian vault and posts it to the PR/MR.
# Inline comments are posted for line-specific findings (BLOCKER, CRITICAL with
# a file:line reference). Everything else posts as a top-level summary comment.
#
# Usage:
#   post-review.sh <pr_number> <obsidian_review_file>
#
# Requires: detect-platform.sh to have been sourced, or REVIEW_PLATFORM /
#           REVIEW_CLI / REVIEW_REPO to be set in the environment.

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────

PR_NUMBER="${1:-}"
REVIEW_FILE="${2:-}"

if [[ -z "$PR_NUMBER" || -z "$REVIEW_FILE" ]]; then
  echo "Usage: post-review.sh <pr_number> <obsidian_review_file>"
  exit 1
fi

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo "❌ Review file not found: $REVIEW_FILE"
  exit 1
fi

# ── Platform env ──────────────────────────────────────────────────────────────

REVIEW_PLATFORM="${REVIEW_PLATFORM:-}"
REVIEW_CLI="${REVIEW_CLI:-}"
REVIEW_REPO="${REVIEW_REPO:-}"

if [[ -z "$REVIEW_PLATFORM" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=detect-platform.sh
  source "$SCRIPT_DIR/detect-platform.sh"
fi

# ── Parse review file ─────────────────────────────────────────────────────────
# Findings with a file:line reference and severity BLOCKER or CRITICAL
# are candidates for inline comments. Everything else goes into the summary.
#
# Expected finding format in the Obsidian file:
#   **[SEVERITY]** `<file>:<line>` — <title>
#   > <why it matters>
#   > <what to do>

SUMMARY_BODY=""
declare -a INLINE_COMMENTS=()

while IFS= read -r line; do
  # Match inline-eligible findings: BLOCKER or CRITICAL with a file:line ref
  if [[ "$line" =~ ^\*\*\[(BLOCKER|CRITICAL)\]\*\*[[:space:]]\`([^:]+):([0-9]+)\` ]]; then
    SEVERITY="${BASH_REMATCH[1]}"
    FILE="${BASH_REMATCH[2]}"
    LINE="${BASH_REMATCH[3]}"
    BODY="$line"
    # Grab the next two lines (the > why and > what)
    read -r why  || true
    read -r what || true
    BODY="${BODY}"$'\n'"${why}"$'\n'"${what}"
    INLINE_COMMENTS+=("${FILE}|${LINE}|${BODY}")
  else
    SUMMARY_BODY="${SUMMARY_BODY}"$'\n'"${line}"
  fi
done < "$REVIEW_FILE"

# ── Post inline comments ──────────────────────────────────────────────────────

INLINE_COUNT=${#INLINE_COMMENTS[@]}
POSTED_INLINE=0
FAILED_INLINE=0

if [[ $INLINE_COUNT -gt 0 ]]; then
  echo "📌 Posting $INLINE_COUNT inline comment(s)..."

  # Fetch diff to build commit SHA and position map
  if [[ "$REVIEW_PLATFORM" == "github" ]]; then
    COMMIT_SHA=$(gh pr view "$PR_NUMBER" --repo "$REVIEW_REPO" --json headRefOid -q .headRefOid)
  elif [[ "$REVIEW_PLATFORM" == "gitlab" ]]; then
    COMMIT_SHA=$(glab mr view "$PR_NUMBER" --repo "$REVIEW_REPO" --output json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" 2>/dev/null || echo "")
  fi

  for entry in "${INLINE_COMMENTS[@]}"; do
    IFS='|' read -r ifile iline ibody <<< "$entry"

    if [[ "$REVIEW_PLATFORM" == "github" ]]; then
      gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${REVIEW_REPO}/pulls/${PR_NUMBER}/comments" \
        -f body="$ibody" \
        -f commit_id="$COMMIT_SHA" \
        -f path="$ifile" \
        -F line="$iline" \
        -f side="RIGHT" \
        &>/dev/null && POSTED_INLINE=$((POSTED_INLINE + 1)) || {
          echo "  ⚠️  Could not post inline comment for $ifile:$iline — will include in summary"
          SUMMARY_BODY="${SUMMARY_BODY}"$'\n\n'"<!-- inline fallback -->"$'\n'"${ibody}"
          FAILED_INLINE=$((FAILED_INLINE + 1))
        }

    elif [[ "$REVIEW_PLATFORM" == "gitlab" ]]; then
      glab api \
        "projects/:id/merge_requests/${PR_NUMBER}/notes" \
        -X POST \
        -f body="$ibody" \
        &>/dev/null && POSTED_INLINE=$((POSTED_INLINE + 1)) || {
          echo "  ⚠️  Could not post inline comment for $ifile:$iline — will include in summary"
          SUMMARY_BODY="${SUMMARY_BODY}"$'\n\n'"${ibody}"
          FAILED_INLINE=$((FAILED_INLINE + 1))
        }
    fi
  done

  echo "  ✅ $POSTED_INLINE posted, $FAILED_INLINE fell back to summary"
fi

# ── Post summary comment ──────────────────────────────────────────────────────

if [[ -n "$SUMMARY_BODY" ]]; then
  echo "💬 Posting summary comment..."

  if [[ "$REVIEW_PLATFORM" == "github" ]]; then
    gh pr comment "$PR_NUMBER" \
      --repo "$REVIEW_REPO" \
      --body "$SUMMARY_BODY"

  elif [[ "$REVIEW_PLATFORM" == "gitlab" ]]; then
    glab mr note "$PR_NUMBER" \
      --repo "$REVIEW_REPO" \
      --message "$SUMMARY_BODY"
  fi

  echo "  ✅ Summary comment posted"
fi

echo ""
echo "✅ Review posted to PR #${PR_NUMBER} on ${REVIEW_REPO}"
