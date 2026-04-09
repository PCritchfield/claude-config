#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$REPO_DIR/skills.txt"

if [ ! -f "$MANIFEST" ]; then
  echo "Error: skills.txt not found at $MANIFEST"
  exit 1
fi

if ! command -v npx &>/dev/null; then
  echo "Error: npx not found. Install Node.js first."
  exit 1
fi

TOTAL=0
INSTALLED=0
FAILED_LIST=""

while IFS= read -r line; do
  # Skip comments and blank lines
  case "$line" in
    \#*|"") continue ;;
  esac

  # Parse: source_repo skill_name
  repo=$(echo "$line" | awk '{print $1}')
  skill=$(echo "$line" | awk '{print $2}')

  if [ -z "$repo" ] || [ -z "$skill" ]; then
    echo "Warning: skipping malformed line: $line"
    continue
  fi

  TOTAL=$((TOTAL + 1))
  echo "[$TOTAL] Installing $skill from $repo..."

  if npx -y skills add "https://github.com/$repo" --skill "$skill" -g -y </dev/null 2>&1 | tail -1; then
    INSTALLED=$((INSTALLED + 1))
  else
    echo "  FAILED: $skill from $repo"
    FAILED_LIST="$FAILED_LIST\n  - $repo/$skill"
  fi
done < "$MANIFEST"

# Fix relative symlinks created by npx — stow makes ~/.claude/skills/ a symlink
# to the repo, so relative paths (../../.agents/skills/) don't resolve correctly.
# Replace with absolute paths to $HOME/.agents/skills/.
SKILLS_DIR="$HOME/.claude/skills"
FIXED=0
for item in "$SKILLS_DIR"/*; do
  [ -L "$item" ] || continue
  name=$(basename "$item")
  target=$(readlink "$item")
  case "$target" in
    ../../.agents/skills/*)
      abs_target="$HOME/.agents/skills/$name"
      if [ -d "$abs_target" ]; then
        rm "$item"
        ln -s "$abs_target" "$item"
        FIXED=$((FIXED + 1))
      fi
      ;;
  esac
done
[ $FIXED -gt 0 ] && echo "Fixed $FIXED relative symlinks for stow compatibility."

echo ""
echo "══════════════════════════════════════"
if [ -n "$FAILED_LIST" ]; then
  FAIL_COUNT=$((TOTAL - INSTALLED))
  echo "WARNING: $FAIL_COUNT skill(s) failed to install:"
  echo -e "$FAILED_LIST"
  echo ""
  echo "Try installing them manually:"
  echo "  npx skills add https://github.com/<repo> --skill <name> -g -y"
  exit 1
else
  echo "All $INSTALLED skills installed successfully."
fi
