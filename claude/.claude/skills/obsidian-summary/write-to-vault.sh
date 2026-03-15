#!/usr/bin/env bash
# write-to-vault.sh
# Writes a note to the Obsidian vault.
# Usage: echo "<markdown>" | bash write-to-vault.sh "<project>" "<label>" "<date>" [subfolder]
#
# Arguments:
#   $1 — project name (e.g. emerald-grove-pet-clinic)
#   $2 — session label (e.g. clinic_issue_1)
#   $3 — date string (e.g. 2026-03-04)
#   $4 — vault subfolder (optional, default: "AI Sessions")
#        e.g. "Digests" for obsidian-digest, "AI Sessions" for obsidian-summary
#
# Environment:
#   OBSIDIAN_VAULT — override vault path (optional)

set -euo pipefail

VAULT="${OBSIDIAN_VAULT:-/Users/philc/Documents/obsidian/Vault}"
FALLBACK_LOG="${HOME}/.claude/obsidian-errors.log"

# ── Args ──────────────────────────────────────────────────────────────────────

PROJECT="${1:-unknown}"
LABEL="${2:-unknown}"
DATE="${3:-$(date +"%Y-%m-%d")}"
SUBFOLDER="${4:-AI Sessions}"

NOTES_DIR="$VAULT/$SUBFOLDER"

# ── Helpers ───────────────────────────────────────────────────────────────────

log_error() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ERROR: $*" >> "$FALLBACK_LOG"
  echo "ERROR: $*" >&2
}

# ── Validate ──────────────────────────────────────────────────────────────────

if [[ ! -d "$VAULT" ]]; then
  log_error "Vault not found at '$VAULT'. Set OBSIDIAN_VAULT or check the path."
  exit 1
fi

if [[ -z "$PROJECT" || "$PROJECT" == "unknown" ]]; then
  log_error "No project name provided."
  exit 1
fi

if [[ -z "$LABEL" || "$LABEL" == "unknown" ]]; then
  log_error "No session label provided."
  exit 1
fi

# ── Read content from stdin ───────────────────────────────────────────────────

CONTENT="$(cat)"

if [[ -z "$CONTENT" ]]; then
  log_error "No content received on stdin."
  exit 1
fi

# ── Build paths ───────────────────────────────────────────────────────────────

SESSION_DIR="$NOTES_DIR/$PROJECT/$LABEL"
SESSION_FILE="$SESSION_DIR/${DATE}-session.md"
INDEX_FILE="$NOTES_DIR/_index.md"

mkdir -p "$SESSION_DIR"

# ── Handle existing file ──────────────────────────────────────────────────────

# If a file already exists for today, append as a second session rather than
# overwriting — two saves in one day is valid.
if [[ -f "$SESSION_FILE" ]]; then
  TIME="$(date +"%H:%M")"
  FINAL_FILE="$SESSION_DIR/${DATE}-${TIME}-session.md"
else
  FINAL_FILE="$SESSION_FILE"
fi

# ── Write ─────────────────────────────────────────────────────────────────────

printf '%s\n' "$CONTENT" > "$FINAL_FILE"

# ── Update index ──────────────────────────────────────────────────────────────

if [[ ! -f "$INDEX_FILE" ]]; then
  mkdir -p "$NOTES_DIR"
  cat > "$INDEX_FILE" <<'EOF'
---
title: AI Sessions Index
tags: [claude-code, index]
---

# AI Sessions

Auto-maintained index of Claude Code session summaries.

| Date | Project | Label | File |
|------|---------|-------|------|
EOF
fi

# Derive the relative Obsidian wiki link
BASENAME="$(basename "$FINAL_FILE" .md)"
INDEX_ENTRY="| $DATE | $PROJECT | $LABEL | [[$PROJECT/$LABEL/$BASENAME]] |"

if ! grep -qF "$PROJECT/$LABEL/$BASENAME" "$INDEX_FILE" 2>/dev/null; then
  echo "$INDEX_ENTRY" >> "$INDEX_FILE"
fi

# ── Report ────────────────────────────────────────────────────────────────────

echo "$FINAL_FILE"
