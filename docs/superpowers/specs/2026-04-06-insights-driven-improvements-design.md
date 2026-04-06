# Insights-Driven Improvements: Charter Hardening, Hook, and `/polish` Skill

**Date:** 2026-04-06
**Status:** Draft
**Source:** Claude Code Insights report (77 sessions, 53 analyzed, 199 commits)

## Problem

Usage analysis across 53 sessions identified three priority friction patterns:

1. **Parallel agent pre-flight failures (C)** — Agents spawn and immediately fail due to dirty worktrees, missing branches, or sandbox permission issues. Time lost to setup, dispatch, and cleanup of failed agents.
2. **CI fix loops (D)** — Code pushed with lint/format/type errors that are only caught by CI, leading to repetitive fix-commit-push cycles. The failures are predictable (ruff, prettier, pyright, tsc) and catchable locally.
3. **Manual polish invocation (E)** — `/simplify` and `/review` must be actively requested every time implementation is complete. The post-implementation workflow (PR creation, parallel polish, external review wait, tech debt capture) is consistent but not encoded anywhere.

Two lower-priority items receive light hardening:
- **TDD slippage (B)** — Working well, but Rincewind lacks explicit authority to flag when an agent skips red-green-refactor.
- **Premature PR merge (A)** — One-time incident, but no output gate currently covers automated reviewer completion.

## Constraints

- SDD workflow skills (`/SDD-1` through `/SDD-4`) are external and not modifiable. Changes must work alongside them, not replace them.
- `settings.json` is global (installed via stow to `~/.claude/`). Hooks must be project-agnostic.
- Agent definitions are solid and well-scoped — friction is at the orchestration layer, not the agent layer.

## Design

### Change 1a: CI Pre-flight Protocol (CLAUDE.md)

New section in the Watch Council Charter, placed after "Context discipline" and before "Agent model allocation."

Instructs Rincewind to detect and run the project's local validation suite before any push:
- **Python**: `ruff check .`, `ruff format --check .`, `pyright`/`mypy`
- **TypeScript/JavaScript**: `npx prettier --check .`, `npx eslint .`, `npx tsc --noEmit`
- **Java**: `mvn checkstyle:check`, `mvn compile`
- **General**: `pre-commit run --all-files` if `.pre-commit-config.yaml` exists

Failures must be fixed before pushing. This is not optional.

**Addresses:** Friction D

### Change 1b: Parallel Agent Pre-flight Protocol (CLAUDE.md)

New section in the Watch Council Charter, adjacent to 1a.

Five-step checklist before dispatching parallel agents:
1. Working tree clean (`git status`)
2. Branches exist (verify local and remote)
3. Quick permission test (spawn trivial agent to confirm sandbox)
4. Worktree directory check (`git worktree list`, prune stale entries)
5. Scope each agent narrowly (one task, one branch, one deliverable)

Any step failure must be resolved before dispatching.

**Addresses:** Friction C

### Change 1c: Post-Implementation Polish (CLAUDE.md)

New section in the Watch Council Charter, adjacent to 1a and 1b.

Instructs Rincewind to suggest the post-implementation polish sequence when SDD-3 tasks are complete or implementation looks PR-ready. The sequence:
1. Create/open PR(s)
2. Run `/simplify` and `/review` in parallel
3. Push fixes
4. Wait for external reviewers (Copilot, CodeRabbit, etc.)
5. Surface tech debt as GitHub issues

Rincewind suggests this proactively. Phil may skip or reorder steps.

**Addresses:** Friction E

### Change 2: Post-Edit Hook (settings.json)

New `"hooks"` key in `settings.json`:

```json
"hooks": {
  "postToolUse": [
    {
      "matcher": "Write|Edit",
      "command": "bash -c '[ -f ruff.toml ] || [ -f pyproject.toml ] && ruff check --fix --quiet . && ruff format --quiet . 2>/dev/null; [ -f .prettierrc ] || [ -f .prettierrc.json ] || [ -f .prettierrc.js ] && npx prettier --write --log-level error . 2>/dev/null; true'"
    }
  ]
}
```

Behavior:
- Fires after every `Edit` or `Write` tool use
- Detects toolchain by config file presence (ruff.toml/pyproject.toml for Python, .prettierrc variants for JS/TS)
- Runs linter/formatter with `--fix` (auto-corrects) and `--quiet` (minimal output)
- No-op for projects without matching config files
- Trailing `; true` ensures hook never blocks

Trade-offs:
- Catches formatting at edit time, not push time
- Runs on every edit including non-code files (fast due to incremental caching)
- `npx prettier` has cold-start cost on first invocation

**Addresses:** Friction D

### Change 3: `/polish` Composite Skill

New skill at `claude/.claude/skills/polish/SKILL.md`.

Orchestrates the post-implementation workflow:

```
1. Pre-flight checks
   - Verify tests pass locally
   - Run CI pre-flight (lint, format, types)
   - Confirm working tree is clean

2. PR creation
   - Detect existing PR or create new one
   - Capture PR number and URL

3. Parallel polish
   - Dispatch /simplify as Agent A
   - Dispatch /review as Agent B (Watch Council via watch-nobby)
   - Both run concurrently

4. Apply fixes
   - Commit and push simplify fixes
   - Commit and push review fixes
   - Re-run CI pre-flight

5. External review gate
   - Check PR status (gh pr checks)
   - Report completed vs pending reviewers
   - Remind: do not merge until all automated reviewers finish

6. Tech debt capture
   - Collect "fix later" / "out of scope" findings from both agents
   - Present numbered list for Phil to approve/edit
   - Create GitHub issues for approved items

7. Summary
   - PR URL, fixes applied, issues created, pending reviewers
```

Design decisions:
- Steps 1 and 4 reuse CI Pre-flight Protocol from Change 1a
- Step 3 runs `/simplify` and `/review` as parallel agents
- Step 5 is a gate (reports status), not a blocker (doesn't loop-wait)
- Step 6 requires Phil's approval before creating issues
- The skill does NOT merge, does NOT run SDD-4, does NOT trigger Obsidian summary
- `/review` retains its existing Obsidian write behavior

**Addresses:** Friction E

### Change 4a: TDD Hardening (CLAUDE.md — SDD section)

One line added to "SDD prompting behaviour":

> During SDD-3, all implementation tasks follow TDD (red-green-refactor) unless the task is explicitly non-code (e.g., documentation, configuration). Rincewind should flag and correct if an implementation agent writes production code before a failing test.

**Addresses:** Friction B (light)

### Change 4b: PR Merge Safety Gate (CLAUDE.md — Output gates)

Fifth gate added to existing output gates:

> **Merge readiness**: do not merge a PR until all automated reviewers (CI, Copilot, CodeRabbit) have completed. Check with `gh pr checks`. A green CI alone is not sufficient if other reviewers are still pending.

**Addresses:** Friction A (light)

### Change 4c: Agent Definitions

No changes. Friction patterns are orchestration-level, not agent-level.

## Files Changed

| File | Change type | Description |
|------|-------------|-------------|
| `claude/.claude/CLAUDE.md` | Edit | Add sections 1a, 1b, 1c, 4a, 4b |
| `claude/.claude/settings.json` | Edit | Add `hooks.postToolUse` |
| `claude/.claude/skills/polish/SKILL.md` | New file | `/polish` composite skill |

## Verification

1. **CLAUDE.md changes**: Read the file and confirm new sections are present, correctly placed, and don't break existing structure.
2. **Hook**: Edit a Python file in a project with `pyproject.toml` and confirm ruff runs automatically. Edit a JS file in a project with `.prettierrc` and confirm prettier runs. Edit a file in a project with neither and confirm no error.
3. **`/polish` skill**: Invoke `/polish` after a completed implementation and confirm it follows the prescribed sequence (PR creation, parallel dispatch, fix push, reviewer check, tech debt surfacing).
4. **TDD hardening**: During SDD-3, intentionally write implementation before test — confirm Rincewind flags it.
5. **Merge gate**: Attempt to merge a PR with pending reviewers — confirm Rincewind blocks and cites the gate.

## Rollback

- **CLAUDE.md**: Revert to previous commit. All changes are additive sections — removal is clean.
- **Hook**: Remove the `"hooks"` key from `settings.json`. No side effects.
- **`/polish` skill**: Delete `claude/.claude/skills/polish/` directory. The skill is self-contained.

## Risks and Assumptions

- **Hook performance**: Assumes ruff and prettier are fast enough on incremental runs to not noticeably slow down editing. If this proves wrong, the hook can be scoped to the edited file rather than `.`.
- **Hook project detection**: Relies on config file presence (ruff.toml, pyproject.toml, .prettierrc). Projects with non-standard config locations won't be detected. This is acceptable — those projects can add project-level hooks.
- **`/polish` parallel dispatch**: Depends on `/simplify` and `/review` being dispatchable as concurrent agents. If sandbox restrictions prevent this, the skill should fall back to sequential execution.
- **Global scope**: All changes apply globally via stow. Project-specific overrides are possible via project-level CLAUDE.md and settings.local.json if needed.

## Summary

| Change | Friction addressed | Mechanism | Effort |
|--------|--------------------|-----------|--------|
| CI Pre-flight | D (CI fix loops) | Charter instruction | Low |
| Parallel Agent Pre-flight | C (agent failures) | Charter checklist | Low |
| Post-Implementation Polish | E (manual invocation) | Charter prompt | Low |
| Post-Edit Hook | D (CI fix loops) | settings.json hook | Low |
| `/polish` Skill | E (manual invocation) | New composite skill | Medium |
| TDD Hardening | B (TDD slippage) | One-line addition | Trivial |
| PR Merge Gate | A (premature merge) | One-line addition | Trivial |
