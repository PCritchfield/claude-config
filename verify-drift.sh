#!/usr/bin/env bash
#
# verify-drift.sh — assert that the live Claude config matches this repo.
#
# This repo claims to be the canonical source for how Claude behaves, but Claude
# reads from ~/.claude. That claim is only true if something checks it. This is
# that something.
#
#   ./verify-drift.sh          # report and exit non-zero on drift (CI)
#   ./verify-drift.sh --warn   # report and always exit 0 (SessionStart hook)
#
# Exit codes: 0 = no drift (or --warn), 1 = drift found, 2 = cannot run.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
STOW_SRC="$REPO_DIR/claude/.claude"
LIVE_DIR="$HOME/.claude"

WARN_ONLY=0
[ "${1:-}" = "--warn" ] && WARN_ONLY=1

DRIFT=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; Z=$'\033[0m'
else
  R=''; G=''; Y=''; D=''; B=''; Z=''
fi

ok()   { printf '  %sok%s    %s\n'   "$G" "$Z" "$1"; }
bad()  { printf '  %sDRIFT%s %s\n'   "$R" "$Z" "$1"; DRIFT=1; }
warn() { printf '  %swarn%s  %s\n'   "$Y" "$Z" "$1"; }
head_() { printf '\n%s%s%s\n' "$B" "$1" "$Z"; }

[ -d "$STOW_SRC" ] || { echo "cannot find stow source at $STOW_SRC" >&2; exit 2; }

# ---------------------------------------------------------------------------
# 0. Which branch is the live config actually on?
#
# ~/.claude/* symlinks point into the repo WORKING TREE, not into git objects.
# So `git checkout` mutates live agent behaviour. Always say where we stand.
# ---------------------------------------------------------------------------
head_ "Live config provenance"
BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo '(detached)')"
SHA="$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
printf '  %sthe live config is whatever is checked out right now%s\n' "$D" "$Z"
printf '  branch %s  head %s\n' "${BRANCH:-(none)}" "$SHA"
if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
  warn "working tree is dirty — live config includes uncommitted changes"
fi

# ---------------------------------------------------------------------------
# 1. Stow linkage: every managed entry must be a symlink resolving into the repo
# ---------------------------------------------------------------------------
head_ "Stow linkage (~/.claude -> repo)"
for src in "$STOW_SRC"/*; do
  name="$(basename "$src")"
  live="$LIVE_DIR/$name"

  if [ ! -e "$live" ] && [ ! -L "$live" ]; then
    bad "$name — missing from ~/.claude (run ./install.sh)"
  elif [ -L "$live" ]; then
    target="$(cd "$(dirname "$live")" && cd "$(dirname "$(readlink "$live")")" 2>/dev/null && pwd)/$(basename "$(readlink "$live")")"
    case "$target" in
      "$REPO_DIR"/*) ok "$name — symlinked into repo" ;;
      *)             bad "$name — symlink points outside the repo: $target" ;;
    esac
  else
    bad "$name — real file/dir in ~/.claude, NOT linked to the repo (drift can accumulate silently)"
  fi
done

# ---------------------------------------------------------------------------
# 2. Un-stowed files: compare content directly
# ---------------------------------------------------------------------------
head_ "Content diff for un-stowed files"
UNSTOWED=0
for src in "$STOW_SRC"/*; do
  name="$(basename "$src")"
  live="$LIVE_DIR/$name"
  [ -L "$live" ] && continue
  [ -f "$src" ] && [ -f "$live" ] || continue
  UNSTOWED=1

  if cmp -s "$src" "$live"; then
    ok "$name — identical"
    continue
  fi

  case "$name" in
    *.json)
      if command -v python3 >/dev/null 2>&1; then
        bad "$name — content differs; structural comparison:"
        REPO_F="$src" LIVE_F="$live" python3 - <<'PY'
import json, os, sys

def flat(o, p=''):
    out = {}
    if isinstance(o, dict):
        for k, v in o.items():
            out.update(flat(v, f'{p}.{k}' if p else k))
    elif isinstance(o, list):
        out[p] = f'<{len(o)} item(s)>'
    else:
        out[p] = o
    return out

try:
    repo = flat(json.load(open(os.environ['REPO_F'])))
    live = flat(json.load(open(os.environ['LIVE_F'])))
except Exception as e:
    print(f'          (could not parse as JSON: {e})')
    sys.exit(0)

only_live = sorted(set(live) - set(repo))
only_repo = sorted(set(repo) - set(live))
changed = sorted(k for k in set(repo) & set(live) if repo[k] != live[k])

for k in only_live:
    print(f'          + live only   {k} = {live[k]!r}')
for k in only_repo:
    print(f'          - repo only   {k} = {repo[k]!r}')
for k in changed:
    print(f'          ~ differs     {k}')
    print(f'                repo: {repo[k]!r}')
    print(f'                live: {live[k]!r}')

n = len(only_live) + len(only_repo) + len(changed)
print(f'          {n} difference(s) — the repo is NOT a faithful record of this machine')
PY
      else
        bad "$name — content differs (install python3 for a structural diff)"
      fi
      ;;
    *)
      bad "$name — content differs"
      ;;
  esac
done
[ "$UNSTOWED" -eq 0 ] && printf '  %snone — every managed file is stowed%s\n' "$D" "$Z"

# ---------------------------------------------------------------------------
# 3. Foreign writes into the stow source
#
# Because ~/.claude/hooks is a symlink into the repo, any tool that installs a
# hook writes into this git working tree. Those files are not ours and will be
# overwritten by whatever put them there.
# ---------------------------------------------------------------------------
head_ "Foreign writes into the stow source"
FOREIGN="$(git -C "$REPO_DIR" ls-files --others --exclude-standard -- claude/.claude 2>/dev/null)"
if [ -z "$FOREIGN" ]; then
  ok "no untracked files inside claude/.claude"
else
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    owner="$(sed -n '1,6p' "$REPO_DIR/$f" 2>/dev/null | grep -iEo 'managed by [a-z0-9_-]+|installed by [a-z0-9_-]+' | head -1)"
    if [ -n "$owner" ]; then
      warn "$f — $owner (third-party; do not commit)"
    else
      warn "$f — untracked inside the stow source"
    fi
  done <<< "$FOREIGN"
fi

# ---------------------------------------------------------------------------
# 4. Skill inventory and stale .gitignore entries
# ---------------------------------------------------------------------------
head_ "Skill inventory"
if [ -d "$STOW_SRC/skills" ]; then
  LIVE_N=$(find "$STOW_SRC/skills" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  TRACKED_N=$(git -C "$REPO_DIR" ls-files claude/.claude/skills/ | cut -d/ -f4 | sort -u | grep -c . || true)
  printf '  %d present, %d tracked in git\n' "$LIVE_N" "$TRACKED_N"

  STALE=0
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    [ -e "$REPO_DIR/$entry" ] || { warn "stale .gitignore entry — $entry no longer exists"; STALE=$((STALE+1)); }
  done < <(grep -E '^claude/\.claude/skills/' "$REPO_DIR/.gitignore" 2>/dev/null || true)
  [ "$STALE" -eq 0 ] && ok "no stale .gitignore skill entries"
else
  warn "no skills directory in the stow source"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
if [ "$DRIFT" -eq 0 ]; then
  printf '%sno drift — the repo is a faithful record of this machine%s\n' "$G" "$Z"
  exit 0
fi

printf '%sdrift detected — this repo does not describe the Claude that is running%s\n' "$R" "$Z"
if [ "$WARN_ONLY" -eq 1 ]; then
  printf '%s(--warn: exiting 0 anyway)%s\n' "$D" "$Z"
  exit 0
fi
exit 1
