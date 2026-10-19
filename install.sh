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

# Discover what stow will manage (top-level entries in the stow package).
#
# settings.json is excluded: it is sync-managed, not stowed. Tools save it by
# writing a temp file and renaming it over the target, which replaces a symlink
# with a regular file. It is listed in claude/.stow-local-ignore, and it must
# also be skipped here — otherwise the conflict step below would move the live
# file into backups and stow would never put anything back.
SYNC_MANAGED="settings.json"
MANAGED_ITEMS=()
for item in "$REPO_DIR/$STOW_PKG/.claude/"*; do
  name="$(basename "$item")"
  [ "$name" = "$SYNC_MANAGED" ] && continue
  MANAGED_ITEMS+=("$name")
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

# Remove links to items this repo no longer holds. stow -R only unstows what is
# still in the package, so these would dangle forever. An item that is back in
# the package is managed again and left alone; otherwise only a link whose
# target is this package's copy of the item is removed.
PKG_DIR="$(cd "$REPO_DIR/$STOW_PKG/.claude" && pwd -P)"
RETIRED_ITEMS=(CLAUDE.md agents commands)
for item in "${RETIRED_ITEMS[@]}"; do
  target_path="$CLAUDE_DIR/$item"
  [ -e "$PKG_DIR/$item" ] && continue
  [ -L "$target_path" ] || continue
  link="$(readlink "$target_path")"
  link_dir="$(cd "$CLAUDE_DIR" && cd "$(dirname "$link")" 2>/dev/null && pwd -P)" || continue
  if [ "$link_dir" = "$PKG_DIR" ] && [ "$(basename "$link")" = "$item" ]; then
    echo "Removing retired symlink: $item"
    rm "$target_path"
  fi
done

# Ensure target directory exists
mkdir -p "$CLAUDE_DIR"

# Stow with explicit target of $HOME
cd "$REPO_DIR"
stow -t "$TARGET" -R "$STOW_PKG"

# Skills that are neither tracked nor ignored are leftovers, e.g. domain skills
# from before the crew plugin bundled them. They still load, and `git add -A`
# would publish them, so name them. (verify-drift.sh reports these too.)
LEFTOVER_SKILLS="$(git -C "$REPO_DIR" ls-files --others --exclude-standard --directory "$STOW_PKG/.claude/skills" || true)"
if [ -n "$LEFTOVER_SKILLS" ]; then
  echo "Warning: untracked, unignored skills. Remove them, or list each in skills.txt and .gitignore:"
  printf '%s\n' "$LEFTOVER_SKILLS" | sed 's/^/  /'
fi

# settings.json: seed from the repo on a fresh machine, or replace a symlink
# left by an older install. An existing real file is this machine's
# authoritative copy and is never overwritten here.
SYNC="$REPO_DIR/$STOW_PKG/.claude/hooks/sync-settings.py"
LIVE_SETTINGS="$CLAUDE_DIR/$SYNC_MANAGED"
if [ ! -e "$LIVE_SETTINGS" ] || [ -L "$LIVE_SETTINGS" ]; then
  python3 "$SYNC" apply
else
  echo "Keeping existing $LIVE_SETTINGS (authoritative on this machine)."
  echo "  To record it in the repo: python3 $SYNC capture"
fi

# Git hooks: post-merge carries settings.json changes pulled from another
# machine into ~/.claude. Guarded — see sync-settings.py.
git -C "$REPO_DIR" config core.hooksPath .githooks

echo ""
echo "Done. Managed items in ~/.claude are now symlinked from this repo."
echo "Symlinked: ${MANAGED_ITEMS[*]}"
echo "Sync-managed: $SYNC_MANAGED (captured on SessionEnd, applied on git pull)"
if [ ${#CONFLICTS[@]} -gt 0 ]; then
  echo "Previous files backed up to: $BACKUP_DIR"
fi
