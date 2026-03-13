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

# Collect unique source repos from the manifest
declare -A REPO_SKILLS

while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// /}" ]] && continue

  # Parse: source_repo skill_name
  repo=$(echo "$line" | awk '{print $1}')
  skill=$(echo "$line" | awk '{print $2}')

  if [ -z "$repo" ] || [ -z "$skill" ]; then
    echo "Warning: skipping malformed line: $line"
    continue
  fi

  # Append skill to repo's list (comma-separated)
  if [ -z "${REPO_SKILLS[$repo]}" ]; then
    REPO_SKILLS[$repo]="$skill"
  else
    REPO_SKILLS[$repo]="${REPO_SKILLS[$repo]},$skill"
  fi
done < "$MANIFEST"

echo "Installing skills from ${#REPO_SKILLS[@]} source repos..."
echo ""

FAILED=()

for repo in "${!REPO_SKILLS[@]}"; do
  skills="${REPO_SKILLS[$repo]}"
  # Convert comma-separated list to multiple --skill flags
  skill_flags=""
  IFS=',' read -ra SKILL_ARRAY <<< "$skills"
  for s in "${SKILL_ARRAY[@]}"; do
    skill_flags="$skill_flags --skill $s"
  done

  echo "── $repo (${#SKILL_ARRAY[@]} skills) ──"
  echo "   Skills: ${skills//,/, }"

  if npx -y skills add "https://github.com/$repo" $skill_flags -g -y 2>&1 | tail -3; then
    echo "   Done."
  else
    echo "   FAILED — will retry individually."
    # Retry each skill individually so one failure doesn't block the rest
    for s in "${SKILL_ARRAY[@]}"; do
      if ! npx -y skills add "https://github.com/$repo" --skill "$s" -g -y 2>&1 | tail -1; then
        echo "   FAILED: $s from $repo"
        FAILED+=("$repo/$s")
      fi
    done
  fi
  echo ""
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "══════════════════════════════════════"
  echo "WARNING: ${#FAILED[@]} skill(s) failed to install:"
  for f in "${FAILED[@]}"; do
    echo "  - $f"
  done
  echo ""
  echo "Try installing them manually:"
  echo "  npx skills add https://github.com/<repo> --skill <name> -g -y"
  exit 1
else
  echo "══════════════════════════════════════"
  echo "All skills installed successfully."
  echo ""
  echo "Installed $(grep -v '^#' "$MANIFEST" | grep -v '^$' | wc -l | tr -d ' ') skills from ${#REPO_SKILLS[@]} repos."
fi
