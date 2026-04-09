#!/bin/bash
# SessionStart hook: load the most recent Obsidian session note for the current project/branch.
# Outputs plain text to stdout, which Claude Code injects as additionalContext.

VAULT="${OBSIDIAN_VAULT:-$HOME/Documents/obsidian/Vault}"
SESSIONS_DIR="$VAULT/AI Sessions"

# Derive project name from git repo root
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
[ -z "$PROJECT" ] && exit 0

# Derive label from branch (strip common prefixes)
BRANCH=$(git branch --show-current 2>/dev/null)
LABEL=$(echo "$BRANCH" | sed 's|^feature/||;s|^fix/||;s|^chore/||;s|^bugfix/||;s|^hotfix/||;s|^refactor/||;s|^improve/||')

# Search strategy: try branch-specific dir first, then project-wide
SEARCH_DIR=""
if [ -n "$LABEL" ] && [ -d "$SESSIONS_DIR/$PROJECT/$LABEL" ]; then
  SEARCH_DIR="$SESSIONS_DIR/$PROJECT/$LABEL"
elif [ -d "$SESSIONS_DIR/$PROJECT" ]; then
  SEARCH_DIR="$SESSIONS_DIR/$PROJECT"
else
  exit 0
fi

# Find the most recently modified session note
LATEST=$(find "$SEARCH_DIR" -name "*-session.md" -type f 2>/dev/null | sort -r | head -1)
[ -z "$LATEST" ] && exit 0

# Read the note (cap at ~4000 chars to avoid bloating context)
CONTENT=$(head -c 4000 "$LATEST")
BASENAME=$(basename "$LATEST")
RELPATH="${LATEST#$VAULT/}"

cat <<EOF
[Prior session loaded from Obsidian: $RELPATH]

$CONTENT
EOF
