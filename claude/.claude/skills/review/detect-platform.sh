#!/usr/bin/env bash
# detect-platform.sh
# Detects the available VCS platform CLI and exports REVIEW_PLATFORM,
# REVIEW_CLI, and REVIEW_REPO for use by the review skill and post-review.sh.
# Exits 1 with a clear message if no supported CLI is found.

set -euo pipefail

# ── Detect CLI ────────────────────────────────────────────────────────────────

REVIEW_PLATFORM=""
REVIEW_CLI=""

if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  REVIEW_PLATFORM="github"
  REVIEW_CLI="gh"
elif command -v glab &>/dev/null && glab auth status &>/dev/null 2>&1; then
  REVIEW_PLATFORM="gitlab"
  REVIEW_CLI="glab"
else
  # Try to hint from remote URL even if CLI isn't available
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ "$REMOTE_URL" == *"github.com"* ]]; then
    echo "❌ GitHub remote detected but 'gh' CLI is not installed or authenticated."
    echo "   Install: https://cli.github.com"
    echo "   Auth:    gh auth login"
  elif [[ "$REMOTE_URL" == *"gitlab"* ]]; then
    echo "❌ GitLab remote detected but 'glab' CLI is not installed or authenticated."
    echo "   Install: https://gitlab.com/gitlab-org/cli"
    echo "   Auth:    glab auth login"
  else
    echo "❌ No supported VCS CLI found (tried: gh, glab)."
    echo "   Ensure you are in a git repo and have gh or glab installed and authenticated."
  fi
  exit 1
fi

# ── Detect repo identifier ────────────────────────────────────────────────────

if [[ "$REVIEW_PLATFORM" == "github" ]]; then
  REVIEW_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
elif [[ "$REVIEW_PLATFORM" == "gitlab" ]]; then
  REVIEW_REPO=$(glab repo view 2>/dev/null | head -1 | awk '{print $NF}' || echo "")
fi

if [[ -z "$REVIEW_REPO" ]]; then
  echo "❌ Could not determine repo identifier. Are you inside a git repository?"
  exit 1
fi

# ── Export ────────────────────────────────────────────────────────────────────

export REVIEW_PLATFORM
export REVIEW_CLI
export REVIEW_REPO

echo "✅ Platform: $REVIEW_PLATFORM"
echo "✅ CLI:      $REVIEW_CLI"
echo "✅ Repo:     $REVIEW_REPO"
