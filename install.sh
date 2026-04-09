#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
STOW_PKG="claude"
TARGET="$HOME"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/pre-stow-$(date +%Y%m%d-%H%M%S)"

# Install stow if missing
if ! command -v stow &>/dev/null; then
  echo "Please install stow: brew install stow"
  exit 1
fi

# Discover what stow will manage (top-level entries in the stow package)
MANAGED_ITEMS=()
for item in "$REPO_DIR/$STOW_PKG/.claude/"*; do
  MANAGED_ITEMS+=("$(basename "$item")")
done

echo "Stow will manage: ${MANAGED_ITEMS[*]}"

# Check for conflicts: real (non-symlink) files/dirs that stow would replace
CONFLICTS=()
for item in "${MANAGED_ITEMS[@]}"; do
  target_path="$CLAUDE_DIR/$item"
  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    CONFLICTS+=("$item")
  fi
done

# Back up and remove conflicts
if [ ${#CONFLICTS[@]} -gt 0 ]; then
  echo "Found ${#CONFLICTS[@]} existing item(s) that conflict with stow:"
  printf "  %s\n" "${CONFLICTS[@]}"
  echo "Backing up to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  for item in "${CONFLICTS[@]}"; do
    target_path="$CLAUDE_DIR/$item"
    echo "  Moving $item → backups/"
    mv "$target_path" "$BACKUP_DIR/$item"
  done
  echo "Backup complete."
fi

# Clean up stale symlinks from previous stow runs
for item in "${MANAGED_ITEMS[@]}"; do
  target_path="$CLAUDE_DIR/$item"
  if [ -L "$target_path" ] && [ ! -e "$target_path" ]; then
    echo "Removing stale symlink: $item"
    rm "$target_path"
  fi
done

# Ensure target directory exists
mkdir -p "$CLAUDE_DIR"

# Stow with explicit target of $HOME
cd "$REPO_DIR"
stow -t "$TARGET" -R "$STOW_PKG"

echo ""
echo "Done. Managed items in ~/.claude are now symlinked from this repo."
echo "Symlinked: ${MANAGED_ITEMS[*]}"
if [ ${#CONFLICTS[@]} -gt 0 ]; then
  echo "Previous files backed up to: $BACKUP_DIR"
fi
