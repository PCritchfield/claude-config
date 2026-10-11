#!/usr/bin/env bash
#
# apply-local-patches.sh — re-apply local fixes to installed Claude Code plugins.
#
# Plugin code lives in ~/.claude/plugins/cache and is replaced on every plugin
# update, so a local fix there silently disappears. This script puts it back.
# It is safe to run any number of times.
#
#   scripts/apply-local-patches.sh          apply where needed, report the rest
#   scripts/apply-local-patches.sh --check  change nothing; exit 1 if a known-broken
#                                           plugin version is installed unpatched
#
# A patch is applied only to the exact plugin version it was written for. Any
# other version is reported with a note on whether the bug still looks present —
# never patched by guesswork.
#
# Patches carried here are fixes for this setup, not upstream changes. See
# docs/claude-workflow.md for why each one exists.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$HOME/.claude/plugins/cache"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

STATUS=0

# ---------------------------------------------------------------------------
# claude-workflow: WorktreeCreate hook reads fields Claude Code never sends
# ---------------------------------------------------------------------------
cw_patch() {
  local patch_version="4.4.1"
  local patch="$REPO_DIR/patches/claude-workflow-$patch_version-worktree-create.patch"
  local root="$CACHE/claude-workflow/claude-workflow"

  [ -d "$root" ] || return 0   # plugin not installed: nothing to do

  local dir version handler
  for dir in "$root"/*/; do
    version="$(basename "$dir")"
    handler="$dir/scripts/worktree-create-handler.sh"
    [ -f "$handler" ] || continue

    if patch --dry-run -R -s -f -p1 -d "$dir" < "$patch" >/dev/null 2>&1; then
      echo "  ok       claude-workflow $version — worktree hook already patched"
      continue
    fi

    if grep -q "jq -r '.worktree_name // empty'" "$handler"; then
      broken=1
    else
      broken=0
    fi

    if [ "$version" != "$patch_version" ]; then
      if [ "$broken" -eq 1 ]; then
        echo "  WARN     claude-workflow $version — worktree hook still reads .worktree_name;"
        echo "           the $patch_version patch was not written for this version. Isolated"
        echo "           agents will fail. Re-derive the patch: see docs/claude-workflow.md"
        STATUS=1
      else
        echo "  ok       claude-workflow $version — no longer reads .worktree_name; patch not needed"
      fi
      continue
    fi

    if [ "$CHECK" -eq 1 ]; then
      echo "  UNPATCHED claude-workflow $version — run scripts/apply-local-patches.sh"
      STATUS=1
      continue
    fi

    if patch -s -f -p1 -d "$dir" < "$patch"; then
      echo "  patched  claude-workflow $version — worktree hook"
    else
      echo "  FAILED   claude-workflow $version — patch did not apply cleanly; nothing changed"
      STATUS=1
    fi
  done
}

echo "local plugin patches:"
cw_patch
exit "$STATUS"
