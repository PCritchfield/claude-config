#!/bin/bash
# PreCompact hook: save a lightweight checkpoint marker to the Obsidian vault.
# PreCompact is non-blocking and observability-only — this is best-effort.
# The real session summary should be done via /obsidian-summary before this fires.

VAULT="${OBSIDIAN_VAULT:-$HOME/Documents/obsidian/Vault}"
SESSIONS_DIR="$VAULT/AI Sessions"

# Derive project and label from git
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
[ -z "$PROJECT" ] && exit 0

BRANCH=$(git branch --show-current 2>/dev/null)
LABEL=$(echo "$BRANCH" | sed 's|^feature/||;s|^fix/||;s|^chore/||;s|^bugfix/||;s|^hotfix/||;s|^refactor/||;s|^improve/||')
[ -z "$LABEL" ] && LABEL="main"

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M%S)
DIR="$SESSIONS_DIR/$PROJECT/$LABEL"
FILE="$DIR/${DATE}-compaction-${TIME}.md"

mkdir -p "$DIR"

cat > "$FILE" <<EOF
---
type: session
project: $PROJECT
branch: $BRANCH
label: $LABEL
date: $DATE
tags:
  - claude-code
  - $PROJECT
  - compaction-checkpoint
status: compacted
---

# Compaction Checkpoint — $DATE $(date +%H:%M)

> [!warning] Auto-saved before context compaction
> This note was created automatically by the PreCompact hook. It marks that a session was active on this branch at this time but context was compressed. Check for a full session summary saved before this point, or start a new \`/obsidian-summary\` in the continued session.

- **Branch:** $BRANCH
- **Project:** $PROJECT
- **Compaction time:** $(date -Iseconds)
EOF

exit 0
