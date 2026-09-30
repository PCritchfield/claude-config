#!/usr/bin/env python3
"""Sync ~/.claude/settings.json with this repo, using git as the sync engine.

Why this exists
  settings.json cannot be stowed. Claude Code and its tools (/config, /doctor,
  /permissions, the desktop app) save it by writing a temp file and renaming it
  over the target, and a rename replaces a symlink with a regular file. The
  first save after `install.sh` silently severs the link, and from then on the
  repo copy is a stale snapshot. Directories survive this; single files do not.

  So the live file is authoritative, and changes move in both directions:

    capture   live -> repo working tree    SessionEnd hook. Never commits:
                                           changes appear in `git status`.
    apply     repo -> live                 git post-merge hook, so a pull
                                           carries settings from another
                                           machine. Guarded (see below).
    check     exit 0 if in sync, 1 if not  Used by verify-drift.sh.

  Everything is written with sorted keys and 2-space indent. Tools reorder
  keys when they save; without normalisation, a reorder looks like a rewrite
  in a line diff. That exact misreading caused a false alarm about deleted
  permission rules on 2026-09-23.

Safety
  capture  Refuses if any env var looks secret. This repo is public; a
           captured file is one `git add` away from publishing it.
           Skips while a rebase, merge or cherry-pick is in progress.
  apply    With --post-merge, acts only when settings.json changed in the
           merge, and refuses to overwrite live changes that were never
           captured. Always backs up the live file before writing it.

Location
  Lives in hooks/ so it is reachable at ~/.claude/hooks/ through the stow
  symlink. The repo root is found by resolving that symlink.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
REPO_REL = "claude/.claude/settings.json"
REPO_SETTINGS = REPO / REPO_REL
LIVE = Path.home() / ".claude" / "settings.json"
BACKUPS = Path.home() / ".claude" / "backups"

SECRET_NAME = re.compile(
    r"token|secret|passw(or)?d|credential|api[_-]?key|private[_-]?key|access[_-]?key",
    re.I,
)
SECRET_VALUE = re.compile(r"^(sk-|ghp_|gho_|github_pat_|xox[abpr]-|AKIA|AIza)")


def normalize(obj) -> str:
    return json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def load(path: Path):
    return json.loads(path.read_text())


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True)


def repo_version(ref: str):
    result = git("show", f"{ref}:{REPO_REL}")
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def find_secrets(settings: dict) -> list[str]:
    found = []
    for name, value in (settings.get("env") or {}).items():
        if SECRET_NAME.search(name) or SECRET_VALUE.search(str(value)):
            found.append(f"env.{name}")
    return found


def git_busy() -> bool:
    gitdir = git("rev-parse", "--git-dir")
    if gitdir.returncode != 0:
        return False
    d = (REPO / gitdir.stdout.strip()).resolve()
    return any((d / m).exists() for m in
               ("rebase-merge", "rebase-apply", "MERGE_HEAD", "CHERRY_PICK_HEAD"))


def backup_live() -> Path | None:
    if not LIVE.exists():
        return None
    BACKUPS.mkdir(parents=True, exist_ok=True)
    dest = BACKUPS / f"settings.json.{datetime.now():%Y%m%d-%H%M%S}"
    dest.write_text(LIVE.read_text())
    return dest


def write_live(obj) -> None:
    """Atomic write, mode 0600. Replaces a stale symlink rather than following it."""
    LIVE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=LIVE.parent, prefix=".settings.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(normalize(obj))
        os.chmod(tmp, 0o600)
        os.replace(tmp, LIVE)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def cmd_capture(_args) -> int:
    if not LIVE.exists():
        print("sync-settings: no live settings.json to capture", file=sys.stderr)
        return 1
    live = load(LIVE)

    secrets = find_secrets(live)
    if secrets:
        print("sync-settings: NOT capturing — secret-looking values in live settings:",
              file=sys.stderr)
        for s in secrets:
            print(f"  {s}", file=sys.stderr)
        print("  This repo is public. Move them out of settings.json, then re-run.",
              file=sys.stderr)
        return 1

    if git_busy():
        print("sync-settings: skipped — git operation in progress in the config repo",
              file=sys.stderr)
        return 0

    new = normalize(live)
    old = REPO_SETTINGS.read_text() if REPO_SETTINGS.exists() else None
    if new == old:
        return 0

    REPO_SETTINGS.write_text(new)
    print(f"sync-settings: captured live settings into {REPO_REL} — "
          f"review with `git -C {REPO} diff`")
    return 0


def cmd_apply(args) -> int:
    live = load(LIVE) if LIVE.exists() else None

    if args.post_merge:
        before, after = repo_version("ORIG_HEAD"), repo_version("HEAD")
        if after is None or normalize(before) == normalize(after):
            return 0
        if live is not None and normalize(live) == normalize(after):
            return 0  # already in sync — e.g. this machine produced the change
        if live is not None and before is not None and normalize(live) != normalize(before):
            print("sync-settings: NOT applying pulled settings.json — this machine has "
                  "live changes that were never captured.", file=sys.stderr)
            print("  Run `python3 ~/.claude/hooks/sync-settings.py capture`, commit, "
                  "and resolve against the pulled version.", file=sys.stderr)
            return 1
        target = after
    else:
        if not REPO_SETTINGS.exists():
            print(f"sync-settings: no {REPO_REL} in the repo", file=sys.stderr)
            return 1
        target = load(REPO_SETTINGS)
        if live is not None and normalize(live) == normalize(target):
            return 0

    saved = backup_live()
    write_live(target)
    note = f" (previous copy: {saved})" if saved else ""
    print(f"sync-settings: applied {REPO_REL} to {LIVE}{note}")
    return 0


def cmd_check(_args) -> int:
    if not (LIVE.exists() and REPO_SETTINGS.exists()):
        return 1
    return 0 if normalize(load(LIVE)) == normalize(load(REPO_SETTINGS)) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync ~/.claude/settings.json with this repo.")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("capture", help="live -> repo working tree")
    apply_p = sub.add_parser("apply", help="repo -> live")
    apply_p.add_argument("--post-merge", action="store_true",
                         help="guarded mode for the git post-merge hook")
    sub.add_parser("check", help="exit 0 if in sync")
    args = parser.parse_args()
    return {"capture": cmd_capture, "apply": cmd_apply, "check": cmd_check}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
