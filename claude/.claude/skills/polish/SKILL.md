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
