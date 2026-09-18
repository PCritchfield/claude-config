#!/usr/bin/env python3
"""Validate the Watch Council configuration as data.

Both defects found in the 2026-09 audit were statically detectable from this
repo alone, and both survived four months because nothing asserted anything:

  Defect 1  Every agent carried `disallowedTools: Write, Edit`, including the
            six the charter grants edit rights. Promotion phrases cannot lift
            a static file, so the implementation half of the council could not
            implement.

  Defect 2  Skills were declared inside `tools:`, which accepts only built-in
            tool names. Skills load via a separate `skills:` key. The whole
            capability layer was inert.

This script asserts against both, plus a handful of cheaper checks.

Exit codes
  0  no errors (warnings may be present)
  1  at least one error
  2  could not run

Baseline ratchet
  Violations recorded in validate-config-baseline.json are reported as warnings
  rather than errors, so CI is green on a repo with known debt while still
  failing on anything NEW. Shrink the baseline as agents are fixed; an empty
  baseline means the debt is cleared. Entries in the baseline that no longer
  reproduce are reported so they can be removed.

Usage
  scripts/validate-config.py [--strict] [--update-baseline]

  --strict           ignore the baseline; fail on every error
  --update-baseline  rewrite the baseline from current violations
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
AGENTS_DIR = REPO / "claude" / ".claude" / "agents"
SKILLS_DIR = REPO / "claude" / ".claude" / "skills"
SETTINGS = REPO / "claude" / ".claude" / "settings.json"
SKILLS_TXT = REPO / "skills.txt"
GITIGNORE = REPO / ".gitignore"
BASELINE = Path(__file__).resolve().parent / "validate-config-baseline.json"

# Built-in Claude Code tools that may legitimately appear in `tools:`.
# Conservative on purpose: an unrecognised name that is NOT a known skill is a
# warning, not an error, so a new built-in tool does not break CI.
BUILTIN_TOOLS = {
    "Bash", "BashOutput", "Edit", "Glob", "Grep", "KillShell", "NotebookEdit",
    "Read", "SlashCommand", "Task", "TodoWrite", "WebFetch", "WebSearch",
    "Write",
}

# Skills provided by the obra/superpowers plugin. They are real skills, but they
# live in neither claude/.claude/skills/ nor skills.txt (skills.txt names them
# only inside a comment, and commit 85ab5c4 removed them from the manifest
# because the plugin supplies them). Without this set they would be reported as
# merely "unrecognised" when found in `tools:`, which understates defect 2.
PLUGIN_SKILLS = {
    "finishing-a-development-branch", "requesting-code-review",
    "systematic-debugging", "test-driven-development",
    "verification-before-completion", "writing-skills",
}

VALID_PERMISSION_MODES = {
    "default", "plan", "acceptEdits", "auto", "dontAsk", "bypassPermissions",
}
VALID_ISOLATION = {"worktree"}

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", re.S)


class Report:
    def __init__(self) -> None:
        self.errors: list[tuple[str, str]] = []
        self.warnings: list[tuple[str, str]] = []

    def error(self, key: str, message: str) -> None:
        self.errors.append((key, message))

    def warn(self, key: str, message: str) -> None:
        self.warnings.append((key, message))


def load_baseline() -> set[str]:
    if not BASELINE.exists():
        return set()
    try:
        data = json.loads(BASELINE.read_text())
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"error: {BASELINE.name} is not valid JSON: {exc}\n")
        sys.exit(2)
    return set(data.get("known_violations", []))


def known_skills() -> set[str]:
    """Skill names this repo knows about, from two sources.

    Directories under claude/.claude/skills/ (whether real or symlinked in by
    install_skills.sh), plus every skill declared in skills.txt. A name in
    either set is a skill, so finding it in `tools:` is defect 2.
    """
    names: set[str] = set(PLUGIN_SKILLS)
    if SKILLS_DIR.is_dir():
        names |= {
            p.name for p in SKILLS_DIR.iterdir()
            if not p.name.startswith(".") and p.name != "synced"
        }
    if SKILLS_TXT.exists():
        for line in SKILLS_TXT.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 2:
                names.add(parts[-1])
    return names


class FrontmatterError(Exception):
    """Frontmatter present but not in a shape this parser understands."""


def parse_frontmatter(path: Path) -> dict | None:
    """Parse the agent-definition frontmatter subset, stdlib only.

    Deliberately not a YAML parser. These files use four shapes:

        key: value                  scalar
        key: >                      folded block, indented continuation
          continued text
        key:                        block list
          - item
        # comment

    Anything else raises FrontmatterError and is reported rather than guessed
    at. A config linter that needs a dependency to read markdown front matter
    is a config linter nobody runs.
    """
    match = FRONTMATTER_RE.match(path.read_text())
    if not match:
        return None

    result: dict[str, object] = {}
    key: str | None = None
    mode: str | None = None  # "folded" | "list"

    for raw in match.group(1).splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue

        indented = raw[0] in " \t"
        stripped = raw.strip()

        if indented and mode == "list" and stripped.startswith("- "):
            result.setdefault(key, []).append(stripped[2:].strip())
            continue

        if indented and mode == "folded":
            result[key] = f"{result[key]} {stripped}".strip()
            continue

        if indented:
            raise FrontmatterError(f"unexpected indented line: {stripped!r}")

        if ":" not in stripped:
            raise FrontmatterError(f"expected 'key: value', got {stripped!r}")

        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip()

        if value in (">", "|", ">-", "|-"):
            result[key] = ""
            mode = "folded"
        elif value == "":
            result[key] = []
            mode = "list"
        else:
            result[key] = value.strip("'\"")
            mode = None

    return result


def split_tools(value) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    return [part.strip() for part in str(value).split(",") if part.strip()]


def check_agents(report: Report, skills: set[str]) -> None:
    if not AGENTS_DIR.is_dir():
        report.error("agents", f"no agents directory at {AGENTS_DIR}")
        return

    for path in sorted(AGENTS_DIR.glob("*.md")):
        rel = path.relative_to(REPO)
        name = path.stem

        try:
            front = parse_frontmatter(path)
        except FrontmatterError as exc:
            report.error(f"{name}:frontmatter", f"{rel}: unparseable YAML frontmatter: {exc}")
            continue

        if front is None:
            report.error(f"{name}:frontmatter", f"{rel}: no YAML frontmatter block")
            continue

        # --- Defect 2: skills declared as tools (ERROR) ------------------
        tools = split_tools(front.get("tools"))
        for tool in tools:
            if tool in skills:
                report.error(
                    f"{name}:skill-in-tools:{tool}",
                    f"{rel}: '{tool}' is a skill, not a tool. `tools:` accepts only "
                    f"built-in tools; move it to a `skills:` list or it will never load.",
                )
            elif tool not in BUILTIN_TOOLS:
                report.warn(
                    f"{name}:unknown-tool:{tool}",
                    f"{rel}: '{tool}' is not a recognised built-in tool or known skill.",
                )

        # --- Defect 2: skills that do not resolve (ERROR) ----------------
        declared = front.get("skills")
        if declared is not None:
            if not isinstance(declared, list):
                report.error(
                    f"{name}:skills-not-list",
                    f"{rel}: `skills:` must be a list, got {type(declared).__name__}.",
                )
            else:
                for skill in (str(s).strip() for s in declared):
                    if skill and skill not in skills:
                        report.error(
                            f"{name}:unresolved-skill:{skill}",
                            f"{rel}: skill '{skill}' is not present in "
                            f"claude/.claude/skills/ and is not declared in skills.txt.",
                        )

        # --- Defect 1: self-contradicting write permissions (WARN) -------
        disallowed = {t.lower() for t in split_tools(front.get("disallowedTools"))}
        body = path.read_text()
        claims_edit = bool(
            re.search(r"may (propose and )?apply edits|you may edit", body, re.I)
        )
        if claims_edit and {"write", "edit"} & disallowed:
            report.warn(
                f"{name}:write-contradiction",
                f"{rel}: body claims edit rights while `disallowedTools` denies "
                f"Write/Edit. `disallowedTools` wins — the claim cannot take effect.",
            )

        if front.get("isolation") == "worktree" and {"write", "edit"} & disallowed:
            report.warn(
                f"{name}:worktree-without-write",
                f"{rel}: `isolation: worktree` is pointless while Write/Edit are "
                f"disallowed — the agent has an isolated tree it cannot write to.",
            )

        # --- cheap schema checks (WARN) ----------------------------------
        mode = front.get("permissionMode")
        if mode is not None and str(mode) not in VALID_PERMISSION_MODES:
            report.warn(
                f"{name}:permission-mode",
                f"{rel}: permissionMode '{mode}' is not one of "
                f"{sorted(VALID_PERMISSION_MODES)}.",
            )

        isolation = front.get("isolation")
        if isolation is not None and str(isolation) not in VALID_ISOLATION:
            report.warn(
                f"{name}:isolation",
                f"{rel}: isolation '{isolation}' is not one of {sorted(VALID_ISOLATION)}.",
            )

        for required in ("name", "description"):
            if not front.get(required):
                report.warn(f"{name}:missing-{required}", f"{rel}: missing `{required}`.")

        if front.get("name") and front["name"] != name:
            report.warn(
                f"{name}:name-mismatch",
                f"{rel}: frontmatter name '{front['name']}' != filename '{name}'.",
            )


def check_settings(report: Report) -> None:
    if not SETTINGS.exists():
        report.warn("settings:missing", f"{SETTINGS.relative_to(REPO)} not found.")
        return
    try:
        json.loads(SETTINGS.read_text())
    except json.JSONDecodeError as exc:
        report.error(
            "settings:invalid-json",
            f"{SETTINGS.relative_to(REPO)}: invalid JSON at line {exc.lineno}: {exc.msg}",
        )


def check_stale_ignores(report: Report) -> None:
    """Report .gitignore entries for skills that no longer exist.

    Only meaningful where the skills are actually installed. The entries name
    gitignored paths, so a fresh checkout — every CI run — has none of them,
    and a naive check reports all 33 as stale. That was 87% of the warning
    output on the first run, which trains readers to skip warnings entirely.

    install_skills.sh creates all of them together, so partial presence means
    real staleness and total absence means an uninstalled tree.
    """
    if not GITIGNORE.exists():
        return

    entries = [
        entry for entry in (line.strip() for line in GITIGNORE.read_text().splitlines())
        if entry.startswith("claude/.claude/skills/") and not entry.endswith("/")
    ]
    if not entries:
        return

    missing = [entry for entry in entries if not (REPO / entry).exists()]

    if len(missing) == len(entries):
        report.warn(
            "gitignore:uninstalled",
            f".gitignore: stale-entry check skipped — none of the {len(entries)} "
            f"ignored skill paths exist, so this is an uninstalled checkout "
            f"(expected in CI). Run ./install_skills.sh to check for stale entries.",
        )
        return

    for entry in missing:
        report.warn(
            f"gitignore:stale:{entry}",
            f".gitignore: '{entry}' no longer exists on disk.",
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true",
                        help="ignore the baseline; fail on every error")
    parser.add_argument("--update-baseline", action="store_true",
                        help="rewrite the baseline from current violations")
    args = parser.parse_args()

    skills = known_skills()
    report = Report()
    check_agents(report, skills)
    check_settings(report)
    check_stale_ignores(report)

    if args.update_baseline:
        BASELINE.write_text(json.dumps(
            {
                "_comment": (
                    "Known violations, reported as warnings so CI stays green on "
                    "existing debt while failing on anything new. Shrink this file "
                    "as agents are fixed; empty means the debt is cleared. "
                    "Regenerate with scripts/validate-config.py --update-baseline"
                ),
                "known_violations": sorted(k for k, _ in report.errors),
            },
            indent=2,
        ) + "\n")
        print(f"baseline updated: {len(report.errors)} violation(s) recorded")
        return 0

    baseline = set() if args.strict else load_baseline()

    hard = [(k, m) for k, m in report.errors if k not in baseline]
    baselined = [(k, m) for k, m in report.errors if k in baseline]
    reproduced = {k for k, _ in report.errors}
    fixed = sorted(baseline - reproduced)

    print(f"agents: {len(sorted(AGENTS_DIR.glob('*.md')))}  "
          f"skills known: {len(skills)}\n")

    for key, message in hard:
        print(f"ERROR    {message}")
    for key, message in report.warnings:
        print(f"warn     {message}")
    for key, message in baselined:
        print(f"baseline {message}")
    for key in fixed:
        print(f"fixed    {key} — no longer reproduces; remove it from the baseline")

    print()
    print(f"{len(hard)} error(s), {len(report.warnings)} warning(s), "
          f"{len(baselined)} baselined, {len(fixed)} fixed")

    if hard:
        print("\nFAIL — new violations are not in the baseline.")
        return 1
    if baselined:
        print("\nPASS — with known debt. Shrink scripts/validate-config-baseline.json.")
    else:
        print("\nPASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
