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

## Dependencies

- **`/simplify`** — A superpowers marketplace skill (from obra/superpowers), already available in the environment via the superpowers plugin. Not a local skill and does not need to be added to `skills.txt`.
- **`/review`** — A local custom skill at `claude/.claude/skills/review/`. Already handles Watch Council orchestration internally (platform detection, watch-nobby dispatch, Obsidian write, PR comment posting).
- **`/create-pull-request`** — A superpowers marketplace skill, already available via the superpowers plugin.

## Design

### Change 1a: CI Pre-flight Protocol (CLAUDE.md)

New section in the Watch Council Charter, placed after "Context discipline" and before "Agent model allocation."

Instructs Rincewind to detect and run the project's local validation suite before any push:
- **Python**: `ruff check .`, `ruff format --check .`, `pyright`/`mypy`
- **TypeScript/JavaScript**: `npx prettier --check .`, `npx eslint .`, `npx tsc --noEmit`
- **Java**: `mvn checkstyle:check`, `mvn compile`
- **General**: `pre-commit run --all-files` if `.pre-commit-config.yaml` exists

Failures must be fixed before pushing. This is not optional.

Note: The post-edit hook (Change 2) catches most formatting issues at edit time. The CI pre-flight serves as a safety net for issues the hook does not cover — type checking (`pyright`, `tsc`), linting rules beyond formatting (`eslint`), and tools not included in the hook. Both layers are intentional (defense in depth).

**Addresses:** Friction D

### Change 1b: Parallel Agent Pre-flight Protocol (CLAUDE.md)

New section in the Watch Council Charter, adjacent to 1a.

Five-step checklist before dispatching parallel agents:
1. Working tree clean (`git status`)
2. Branches exist (verify local and remote)
3. Quick permission test — spawn a single agent with a trivial Bash command (e.g., `echo "sandbox ok"`) and confirm it completes. If it fails with a permission error, do not dispatch the full batch.
4. Worktree directory check (`git worktree list`, prune stale entries)
5. Scope each agent narrowly (one task, one branch, one deliverable)

Any step failure must be resolved before dispatching.

**Addresses:** Friction C

### Change 1c: Post-Implementation Polish (CLAUDE.md)

New section in the Watch Council Charter, adjacent to 1a and 1b.

Instructs Rincewind to suggest the post-implementation polish sequence when SDD-3 tasks are complete or implementation looks PR-ready. The expected sequence relative to SDD stages is: SDD-3 completes → `/polish` runs → SDD-4 validates (if applicable). The sequence:
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
      "command": "bash -c 'FILES=$(git diff --name-only 2>/dev/null); [ -z \"$FILES\" ] && exit 0; { [ -f ruff.toml ] || [ -f pyproject.toml ]; } && echo \"$FILES\" | grep -qE \"\\.py$\" && ruff check --fix --quiet $(echo \"$FILES\" | grep -E \"\\.py$\") && ruff format --quiet $(echo \"$FILES\" | grep -E \"\\.py$\") 2>/dev/null; { [ -f .prettierrc ] || [ -f .prettierrc.json ] || [ -f .prettierrc.js ]; } && echo \"$FILES\" | grep -qE \"\\.(js|ts|jsx|tsx|css|json)$\" && npx prettier --write --log-level error $(echo \"$FILES\" | grep -E \"\\.(js|ts|jsx|tsx|css|json)$\") 2>/dev/null; true'"
    }
  ]
}
```

Behavior:
- Fires after every `Edit` or `Write` tool use
- Uses `git diff --name-only` to scope to changed files only — does not touch files outside the current task
- Detects toolchain by config file presence (ruff.toml/pyproject.toml for Python, .prettierrc variants for JS/TS)
- Filters changed files by extension before passing to the formatter (`.py` for ruff, `.js/.ts/.jsx/.tsx/.css/.json` for prettier)
- Uses `{ ...; }` grouping to avoid shell operator precedence bugs with `||` and `&&`
- No-op if no files have changed or project has no matching config files
- Trailing `; true` ensures hook never blocks

Trade-offs:
- Catches formatting at edit time, not push time
- Scoped to changed files only — no surprise modifications to unrelated files
- `npx prettier` has cold-start cost on first invocation
- `git diff --name-only` only catches unstaged changes; staged-then-edited files are still covered since they appear in diff

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
   - Dispatch /review as Agent B
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

1. **CLAUDE.md changes**: Read the file and confirm new sections (CI Pre-flight, Parallel agent pre-flight, Post-implementation polish) are present between "Context discipline" and "Agent model allocation." The output gates section should now have 5 items. The SDD prompting behaviour section should include the TDD enforcement line. Expected: `grep -c "## CI Pre-flight\|## Parallel agent pre-flight\|## Post-implementation polish" CLAUDE.md` returns 3.
2. **Hook (Python)**: In a project with `pyproject.toml`, introduce a formatting violation (e.g., extra whitespace), use `Edit` tool. Expected: hook output shows ruff ran, file is auto-corrected, no manual intervention needed.
3. **Hook (JS/TS)**: In a project with `.prettierrc`, introduce a formatting violation, use `Edit` tool. Expected: hook output shows prettier ran, file is auto-corrected.
4. **Hook (no toolchain)**: In a project with neither config file, use `Edit` tool. Expected: no hook output, no error, edit completes normally.
5. **`/polish` skill**: Invoke `/polish` after a completed implementation. Expected: skill creates PR (or detects existing), dispatches simplify and review as parallel agents, pushes fix commits, reports `gh pr checks` status, and surfaces tech debt candidates for approval.
6. **TDD hardening**: During SDD-3, intentionally write implementation before test. Expected: Rincewind flags the violation and requests the failing test be written first.
7. **Merge gate**: Attempt to merge a PR with pending reviewers. Expected: Rincewind cites output gate 5 and blocks until `gh pr checks` shows all reviewers complete.

## Rollback

- **CLAUDE.md**: Revert to previous commit. All changes are additive sections — removal is clean.
- **Hook**: Remove the `"hooks"` key from `settings.json`. No side effects.
- **`/polish` skill**: Delete `claude/.claude/skills/polish/` directory. The skill is self-contained.

## Risks and Assumptions

- **Hook performance**: Hook is scoped to changed files via `git diff --name-only`, so it only processes files that have been modified. Performance should be fast for typical edit sessions. If `npx prettier` cold-start is too slow, consider installing prettier globally or using a project-local `node_modules/.bin/prettier` path.
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
