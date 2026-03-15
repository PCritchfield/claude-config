#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install stow if missing
if ! command -v stow &>/dev/null; then
  echo "Please install stow: brew install stow"
  exit 1
fi

cd "$REPO_DIR"
stow -R claude

echo "Done. ~/.claude is now managed by stow."
