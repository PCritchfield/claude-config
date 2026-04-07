# Insights-Driven Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce three friction patterns (parallel agent pre-flight failures, CI fix loops, manual polish invocation) by adding charter sections, a post-edit hook, and a `/polish` composite skill.

**Architecture:** All changes are additive to the existing claude-config structure. CLAUDE.md gets three new charter sections and two one-line additions. settings.json gets a hooks block. A new `/polish` skill follows the same SKILL.md pattern as the existing `/review` skill.

**Tech Stack:** Markdown (CLAUDE.md, SKILL.md), JSON (settings.json), Bash (hook command)

**Spec:** `docs/superpowers/specs/2026-04-06-insights-driven-improvements-design.md`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `claude/.claude/CLAUDE.md` | Edit | Add CI Pre-flight, Parallel Agent Pre-flight, Post-implementation polish sections; add TDD hardening line; add merge readiness gate |
| `claude/.claude/settings.json` | Edit | Add `hooks.postToolUse` for auto-linting |
| `claude/.claude/skills/polish/SKILL.md` | Create | `/polish` composite skill |

---

## Chunk 1: CLAUDE.md Charter Additions

### Task 1: Add Output Gate 5 (PR Merge Safety)

**Files:**
- Modify: `claude/.claude/CLAUDE.md:289-294` (Output gates section)

- [ ] **Step 1: Read the current output gates section**

Read `claude/.claude/CLAUDE.md` lines 289-294 to confirm the exact text of the existing 4 output gates.

- [ ] **Step 2: Add gate 5 after gate 4**

After line 294 (`4) **Scope control**: smallest viable change first`), add:

```markdown
5) **Merge readiness**: do not merge a PR until all automated reviewers (CI, Copilot, CodeRabbit) have completed. Check with `gh pr checks`. A green CI alone is not sufficient if other reviewers are still pending.
```

- [ ] **Step 3: Verify the edit**

Read `claude/.claude/CLAUDE.md` lines 289-296 and confirm 5 numbered gates are present.

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/CLAUDE.md
git commit -m "feat(charter): add merge readiness output gate

Adds gate 5 requiring all automated reviewers (CI, Copilot,
CodeRabbit) to complete before merging. Addresses friction A
from insights analysis."
```

---

### Task 2: Add CI Pre-flight Protocol Section

**Files:**
- Modify: `claude/.claude/CLAUDE.md:349-358` (between "Context discipline" and "Agent model allocation")

- [ ] **Step 1: Read the insertion point**

Read `claude/.claude/CLAUDE.md` lines 349-358 to confirm the exact text around "Context discipline" and "Agent model allocation."

- [ ] **Step 2: Insert CI Pre-flight section**

After the "Context discipline" section (after the blank line following line 352) and before "## Agent model allocation" (line 354), insert:

```markdown

## CI Pre-flight

Before pushing any branch, Rincewind must run the project's local validation suite. The specific commands depend on what the project uses — detect and run what's available:

- **Python**: `ruff check .`, `ruff format --check .`, `pyright` (or `mypy`)
- **TypeScript/JavaScript**: `npx prettier --check .`, `npx eslint .`, `npx tsc --noEmit`
- **Java**: `mvn checkstyle:check`, `mvn compile`
- **General**: run pre-commit hooks if `.pre-commit-config.yaml` exists (`pre-commit run --all-files`)

If any check fails, fix it before pushing. Do not push known-broken code and hope CI will be more forgiving than the local toolchain — it won't be, and the fix-commit-push loop that follows is exactly the kind of improbable doom we're trying to avoid.

The post-edit hook (see `settings.json`) catches most formatting issues at edit time. This pre-flight serves as a safety net for issues the hook does not cover — type checking (`pyright`, `tsc`), linting rules beyond formatting (`eslint`), and tools not included in the hook. Both layers are intentional (defense in depth).

This is not optional. A push without local validation is a push made in fear, and Rincewind knows better than anyone that running *toward* danger never ends well.
```

- [ ] **Step 3: Verify the edit**

Read the file and confirm the new section appears between "Context discipline" and "Agent model allocation."

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/CLAUDE.md
git commit -m "feat(charter): add CI pre-flight protocol

Requires Rincewind to run project-appropriate lint, format, and
type checks before pushing. Detects toolchain by project config.
Defense in depth with the post-edit hook. Addresses friction D."
```

---

### Task 3: Add Parallel Agent Pre-flight Protocol Section

**Files:**
- Modify: `claude/.claude/CLAUDE.md` (immediately after the CI Pre-flight section from Task 2)

- [ ] **Step 1: Read the insertion point**

Read `claude/.claude/CLAUDE.md` to find the end of the CI Pre-flight section added in Task 2.

- [ ] **Step 2: Insert Parallel Agent Pre-flight section**

Immediately after the CI Pre-flight section, before "## Agent model allocation", insert:

```markdown

## Parallel agent pre-flight

Before dispatching parallel agents (whether via worktrees or concurrent subagents), run this checklist. Do not skip steps. Agents that faceplant on launch waste more time than the checklist takes.

1. **Working tree clean?** — `git status` on the base branch. Uncommitted changes will poison worktrees.
2. **Branches exist?** — If agents need specific branches, verify they exist locally and remotely. Create them before dispatching.
3. **Quick permission test** — Spawn a single agent with a trivial Bash command (e.g., `echo "sandbox ok"`) and confirm it completes. If it fails with a permission error, do not dispatch the full batch.
4. **Worktree directory check** — If using git worktrees, verify the target parent directory exists and has no stale worktrees from previous sessions (`git worktree list`). Prune stale entries with `git worktree prune` if needed.
5. **Scope each agent narrowly** — Each agent gets one task, one branch, one clear deliverable. Agents with broad mandates are agents that drift.

If any step fails, fix it before dispatching. A failed pre-flight is cheaper than N failed agents.
```

- [ ] **Step 3: Verify the edit**

Read the file and confirm the section appears after CI Pre-flight and before Agent model allocation.

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/CLAUDE.md
git commit -m "feat(charter): add parallel agent pre-flight protocol

Five-step checklist before dispatching parallel agents: clean
working tree, branch verification, sandbox permission test,
worktree check, and narrow scoping. Addresses friction C."
```

---

### Task 4: Add Post-Implementation Polish Section

**Files:**
- Modify: `claude/.claude/CLAUDE.md` (immediately after the Parallel Agent Pre-flight section from Task 3)

- [ ] **Step 1: Read the insertion point**

Read `claude/.claude/CLAUDE.md` to find the end of the Parallel Agent Pre-flight section added in Task 3.

- [ ] **Step 2: Insert Post-Implementation Polish section**

Immediately after the Parallel Agent Pre-flight section, before "## Agent model allocation", insert:

```markdown

## Post-implementation polish

After SDD-3 tasks are complete (or after any implementation session that produces PR-ready code), Rincewind should prompt the following sequence. This is not optional — suggest it before Phil has to ask. The expected sequence relative to SDD stages is: SDD-3 completes → `/polish` runs → SDD-4 validates (if applicable).

1. **Create/open PR(s)** — using `/create-pull-request` or `gh pr create`
2. **Run `/simplify` and `/review` in parallel** — dispatch both as concurrent agents against the PR branch
3. **Push fixes** from simplify and review findings
4. **Wait for external reviewers** — do not merge until Copilot and any other automated reviewers have completed. Check with `gh pr checks`.
5. **Surface tech debt** — any "fix later" findings from simplify or review should be captured as GitHub issues, tagged appropriately

Rincewind suggests this sequence when implementation looks complete. Phil may skip or reorder steps, but the default is: PR → parallel polish → push → wait → tech debt issues.

For a streamlined invocation, use `/polish` which orchestrates this entire sequence.
```

- [ ] **Step 3: Verify the edit**

Read the file and confirm the section appears after Parallel Agent Pre-flight and before Agent model allocation.

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/CLAUDE.md
git commit -m "feat(charter): add post-implementation polish prompt

Instructs Rincewind to proactively suggest the PR → simplify +
review → push → wait → tech debt sequence after SDD-3 or any
implementation session. References /polish skill. Addresses
friction E."
```

---

### Task 5: Add TDD Hardening Line

**Files:**
- Modify: `claude/.claude/CLAUDE.md` (SDD prompting behaviour section)

**Note:** Tasks 2-4 insert ~40 lines earlier in the file, shifting all subsequent line numbers. Do NOT rely on original line numbers. Search for the heading `## SDD prompting behaviour` to find the actual location.

- [ ] **Step 1: Find the SDD prompting behaviour section**

Search for `## SDD prompting behaviour` in `claude/.claude/CLAUDE.md`. Read that section and confirm the last bullet is `- Agents should not re-ask questions already answered in an existing spec.`

- [ ] **Step 2: Add TDD enforcement line**

After the line `- Agents should not re-ask questions already answered in an existing spec.`, add:

```markdown
- During SDD-3, all implementation tasks follow TDD (red-green-refactor) unless the task is explicitly non-code (e.g., documentation, configuration). Rincewind should flag and correct if an implementation agent writes production code before a failing test.
```

- [ ] **Step 3: Verify the edit**

Search for `## SDD prompting behaviour` again and confirm the TDD enforcement line is the last bullet in that section.

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/CLAUDE.md
git commit -m "feat(charter): harden TDD enforcement in SDD-3

Gives Rincewind explicit authority to flag and correct when an
implementation agent skips the red-green-refactor cycle during
SDD-3 task execution. Addresses friction B."
```

---

## Chunk 2: Post-Edit Hook

### Task 6: Add hooks to settings.json

**Files:**
- Modify: `claude/.claude/settings.json:163-169` (before closing brace)

- [ ] **Step 1: Read current settings.json**

Read `claude/.claude/settings.json` to confirm the full structure and identify the insertion point (before the final `}`).

- [ ] **Step 2: Add the hooks block**

The statusLine block ends with `  }` on line 168. Change that to `  },` (add trailing comma), then insert the following block before the root closing `}` on line 169:

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

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json; json.load(open('claude/.claude/settings.json'))"`

Expected: No output (valid JSON). If it fails, fix the syntax.

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/settings.json
git commit -m "feat(hooks): add post-edit auto-format hook

Fires after every Write/Edit, scopes to changed files via git
diff --name-only, detects ruff (Python) and prettier (JS/TS) by
config file presence. Auto-fixes formatting at edit time.
Addresses friction D."
```

---

## Chunk 3: `/polish` Composite Skill

### Task 7: Create the `/polish` skill

**Files:**
- Create: `claude/.claude/skills/polish/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p claude/.claude/skills/polish
```

- [ ] **Step 2: Write SKILL.md**

Create `claude/.claude/skills/polish/SKILL.md` with the following content:

```markdown
---
name: polish
description: Post-implementation workflow — creates PR, runs /simplify and /review in parallel, pushes fixes, checks external reviewers, and surfaces tech debt as GitHub issues. Use after SDD-3 tasks are complete or when implementation is PR-ready.
---

# /polish — Post-Implementation Polish

## Overview

This skill orchestrates the post-implementation workflow: PR creation, parallel code polish (simplify + review), external reviewer gate, and tech debt capture. It encodes the sequence that Rincewind suggests after SDD-3 completion.

The expected position in the SDD lifecycle is: **SDD-3 completes → `/polish` → SDD-4 validates**.

---

## Pre-requisites

- Implementation is complete (all SDD-3 tasks done, or code is PR-ready)
- All changes are committed to the working branch
- The branch is pushed to the remote

If any of these are not met, the skill will prompt you to fix them before proceeding.

---

## Step 1 — Pre-flight checks

Run these checks before proceeding. Stop and fix any failures.

### 1a. Tests pass locally

Detect and run the project's test suite:
- **Python**: `pytest` or `python -m pytest`
- **TypeScript/JavaScript**: `npm test` or `npx vitest` or `npx jest`
- **Java**: `mvn test` or `gradle test`

If tests fail, stop. Fix the tests before polishing.

### 1b. CI pre-flight (lint, format, types)

Run the project's local validation suite (per the CI Pre-flight Protocol in CLAUDE.md):
- **Python**: `ruff check .`, `ruff format --check .`, `pyright` (or `mypy`)
- **TypeScript/JavaScript**: `npx prettier --check .`, `npx eslint .`, `npx tsc --noEmit`
- **Java**: `mvn checkstyle:check`, `mvn compile`
- **General**: `pre-commit run --all-files` if `.pre-commit-config.yaml` exists

If any check fails, fix it before proceeding.

### 1c. Working tree clean

```bash
git status
```

If there are uncommitted changes, commit or stash them. The working tree must be clean.

---

## Step 2 — PR creation

Check if a PR already exists for the current branch:

```bash
gh pr view --json number,url 2>/dev/null
```

- **If a PR exists**: capture the number and URL. Report it.
- **If no PR exists**: use `/create-pull-request` to create one. If that skill is unavailable, fall back to `gh pr create`.

Capture the **PR number** and **PR URL** for use in later steps.

---

## Step 3 — Parallel polish

Dispatch two agents concurrently:

**Agent A — Simplify:**
Invoke `/simplify` against the current branch. This reviews changed code for reuse, quality, and efficiency opportunities.

**Agent B — Review:**
Invoke `/review` against the current PR. This runs the full Watch Council review via watch-nobby, writes findings to Obsidian, and identifies issues by severity.

Both agents run in parallel. Wait for both to complete before proceeding.

If parallel dispatch fails (sandbox restrictions), fall back to running them sequentially: simplify first, then review.

---

## Step 4 — Apply fixes

### 4a. Apply simplify fixes

Review the simplify findings. Apply fixes for any actionable items. Stage and commit:

```bash
git add <fixed files>
git commit -m "refactor: apply simplify findings"
```

### 4b. Apply review fixes

Review the council findings. Apply fixes for any BLOCKER or CRITICAL items. Stage and commit:

```bash
git add <fixed files>
git commit -m "fix: address review findings"
```

### 4c. Re-run CI pre-flight

Run the same CI pre-flight checks from Step 1b to confirm fixes haven't introduced new issues.

### 4d. Push

```bash
git push
```

---

## Step 5 — External review gate

Check the PR's review status:

```bash
gh pr checks "$PR_NUMBER"
```

Report the results:
- Which checks have completed (and their status)
- Which checks are still pending
- Which automated reviewers (Copilot, CodeRabbit) have not yet posted

**Remind:** Do not merge until all automated reviewers have completed. A green CI alone is not sufficient if other reviewers are still pending.

This is a gate, not a blocker — report status and let Phil decide when to proceed.

---

## Step 6 — Tech debt capture

Collect findings from both simplify and review that were categorized as:
- "Fix later"
- "Out of scope"
- "Tech debt"
- MINOR or INFO severity findings that represent improvement opportunities

Present them as a numbered list:

```
Tech debt candidates from this PR:

1. [file:line] Description of finding (source: simplify/review)
2. [file:line] Description of finding (source: simplify/review)
...

Which items should I create as GitHub issues? (Enter numbers, "all", or "none")
```

For approved items, create GitHub issues:

```bash
gh issue create --title "Tech debt: <brief description>" \
  --body "Found during /polish of PR #<number>.

**File:** <file:line>
**Finding:** <description>
**Source:** <simplify|review>"
```

---

## Step 7 — Summary

Report the final state:

```
## Polish Summary

**PR:** #<number> — <url>
**Simplify fixes:** <count> commits
**Review fixes:** <count> commits
**CI status:** <passing|failing>
**Pending reviewers:** <list or "none">
**Tech debt issues created:** <count> (<list of issue numbers>)
```

---

## What this skill does NOT do

- **Merge** — merging is Phil's call, not an automated step
- **SDD-4 validation** — that is a separate stage with different intent
- **Obsidian summary** — use `/obsidian-summary` separately if needed
- **Branch cleanup** — too destructive to automate silently

---

## Notes

- `/simplify` is a superpowers marketplace skill (obra/superpowers). It does not need local installation.
- `/review` is a local skill at `~/.claude/skills/review/`. It handles Watch Council orchestration internally.
- `/create-pull-request` is a superpowers marketplace skill. It does not need local installation.
- The CI pre-flight checks in Steps 1b and 4c follow the same protocol defined in the Watch Council Charter.
```

- [ ] **Step 3: Verify the file exists and is well-formed**

Read `claude/.claude/skills/polish/SKILL.md` and confirm:
- Frontmatter has `name: polish` and `description`
- All 7 steps are present
- The "What this skill does NOT do" section is present

- [ ] **Step 4: Commit**

```bash
git add claude/.claude/skills/polish/SKILL.md
git commit -m "feat(skills): add /polish composite skill

Orchestrates post-implementation workflow: PR creation, parallel
simplify + review dispatch, fix application, external reviewer
gate, and tech debt issue capture. Addresses friction E."
```

---

## Chunk 4: Verification

### Task 8: Verify all changes

**Files:**
- Read: `claude/.claude/CLAUDE.md`
- Read: `claude/.claude/settings.json`
- Read: `claude/.claude/skills/polish/SKILL.md`

- [ ] **Step 1: Verify CLAUDE.md structure**

```bash
grep -c "## CI Pre-flight\|## Parallel agent pre-flight\|## Post-implementation polish" claude/.claude/CLAUDE.md
```

Expected: `3`

```bash
grep -c "Merge readiness" claude/.claude/CLAUDE.md
```

Expected: `1`

```bash
grep -c "Rincewind should flag and correct" claude/.claude/CLAUDE.md
```

Expected: `1`

- [ ] **Step 2: Verify settings.json is valid JSON with hooks**

```bash
python3 -c "import json; d=json.load(open('claude/.claude/settings.json')); print('hooks' in d, 'postToolUse' in d.get('hooks', {}))"
```

Expected: `True True`

- [ ] **Step 3: Verify /polish skill exists**

```bash
ls claude/.claude/skills/polish/SKILL.md
```

Expected: file exists

```bash
grep -c "name: polish" claude/.claude/skills/polish/SKILL.md
```

Expected: `1`

- [ ] **Step 4: Verify section ordering in CLAUDE.md**

```bash
grep -n "## Context discipline\|## CI Pre-flight\|## Parallel agent pre-flight\|## Post-implementation polish\|## Agent model allocation" claude/.claude/CLAUDE.md
```

Expected: 5 lines in ascending line-number order:
1. `## Context discipline`
2. `## CI Pre-flight`
3. `## Parallel agent pre-flight`
4. `## Post-implementation polish`
5. `## Agent model allocation`

- [ ] **Step 5: Run git log to confirm all commits**

```bash
git log --oneline -8
```

Expected: 7 new commits (one per task, Tasks 1-7) on top of the spec commits.
