---
name: review
description: Use when asked to review a pull request or merge request. Fetches open PRs/MRs, lets the user select one, runs the Watch Council review via watch-nobby, writes the report to Obsidian, and prompts to post findings back to the PR/MR.
---

# /review — Watch Council PR Review

## Overview

This skill orchestrates a full Watch Council review of an open pull request or merge request. It detects the platform, fetches open PRs, routes the diff through **watch-nobby** for council assignment, writes the structured report to the Obsidian vault, and offers to post findings back to the PR/MR as inline and summary comments.

Rincewind is not involved. This is council business.

---

## Skill Directory

```
~/.claude/skills/review/
├── SKILL.md               ← this file
├── detect-platform.sh     ← gh / glab detection
└── post-review.sh         ← diff position mapping + comment posting
```

---

## Step 1 — Detect platform

Run `detect-platform.sh` from the skill directory:

```bash
source ~/.claude/skills/review/detect-platform.sh
```

If it exits non-zero, surface the error message verbatim and stop. Do not proceed without a confirmed platform.

---

## Step 2 — List open PRs/MRs

**GitHub:**
```bash
gh pr list --repo "$REVIEW_REPO" --state open \
  --json number,title,author,headRefName,baseRefName,createdAt \
  --template '{{range .}}#{{.number}} {{.title}} ({{.author.login}}, {{.headRefName}} → {{.baseRefName}}){{"\n"}}{{end}}'
```

**GitLab:**
```bash
glab mr list --repo "$REVIEW_REPO" --state opened
```

Present the list to the user and ask which PR/MR to review. Accept a number or unambiguous title fragment. If there are no open PRs/MRs, say so and stop.

---

## Step 3 — Fetch PR metadata and diff

**GitHub:**
```bash
# Metadata
gh pr view "$PR_NUMBER" --repo "$REVIEW_REPO" \
  --json number,title,author,body,headRefName,baseRefName,files

# Diff
gh pr diff "$PR_NUMBER" --repo "$REVIEW_REPO"
```

**GitLab:**
```bash
# Metadata
glab mr view "$PR_NUMBER" --repo "$REVIEW_REPO" --output json

# Diff
glab mr diff "$PR_NUMBER" --repo "$REVIEW_REPO"
```

---

## Step 4 — Apply ignore rules

Before passing the diff to watch-nobby:

1. Check for `.claude-review-ignore` in the repo root. If present, read it and apply patterns (same syntax as `.gitignore`).
2. Apply hardcoded defaults regardless:

```
# Lock files — never ingest
package-lock.json
yarn.lock
pnpm-lock.yaml
pnpm-lock.yml
Gemfile.lock
poetry.lock
cargo.lock
composer.lock
*.lock

# Generated / dist — never ingest
dist/
build/
*.min.js
*.min.css
```

3. Handle SDD spec files (`docs/specs/`) separately — do not ignore, but do not pass diff content. Pass only the file paths and a diff stat (additions/deletions count).

---

## Step 5 — Invoke watch-nobby

Pass to watch-nobby:
- PR number, title, author, description, source branch, target branch
- Full list of changed files (post-ignore)
- Cleaned diff (ignored files removed, spec files replaced with stat-only entries)
- Repo root path (for `.claude-review-ignore` reference)

watch-nobby will:
- Categorise the diff by domain
- Surface SDD spec flags
- Summon the relevant council agents (always including watch-carrot)
- Brief each agent with only their relevant diff sections
- Collect findings and assemble the structured report

---

## Step 6 — Write report to Obsidian

Determine paths:

```bash
PROJECT=$(basename "$(git rev-parse --show-toplevel)")
VAULT="${OBSIDIAN_VAULT:-$HOME/Documents/obsidian/Vault}"
PR_SLUG="${PR_NUMBER}-$(echo "$PR_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')"
REVIEW_PATH="${VAULT}/AI Sessions/${PROJECT}/reviews/${PR_SLUG}.md"
```

Create the directory if it doesn't exist:
```bash
mkdir -p "$(dirname "$REVIEW_PATH")"
```

Write the report with a frontmatter header:

```markdown
---
pr: <number>
title: <title>
author: <author>
branch: <head> → <base>
repo: <repo>
reviewed_at: <ISO timestamp>
platform: <github|gitlab>
---

<watch-nobby report content>
```

Confirm the path to the user:
```
📝 Review written to:
   <REVIEW_PATH>
```

---

## Step 7 — Prompt to post

```
Review complete. What would you like to do?

  [1] Post to PR as-is
  [2] Open review file first, then post
  [3] Don't post — keep local only
```

If **1**: run `post-review.sh` immediately.

If **2**: display the vault path, tell the user to edit and save, then ask:
```
Ready to post? [y/n]
```
On confirmation, run `post-review.sh`.

If **3**: confirm the review is saved and remind the user of the path. Done.

---

## Step 8 — Post (if confirmed)

```bash
bash ~/.claude/skills/review/post-review.sh "$PR_NUMBER" "$REVIEW_PATH"
```

Surface any errors from the script verbatim. On success:

```
✅ Review posted to PR #<number>
   <PR URL>
```

---

## Ignore file format (`.claude-review-ignore`)

Standard gitignore syntax. Example:

```gitignore
# Project-specific generated files
src/generated/
*.pb.go

# Test fixtures with large data
tests/fixtures/large/

# Vendored code
vendor/
```

---

## Severity reference

| Badge | Level | Meaning |
|-------|-------|---------|
| 🔴 | BLOCKER | Must resolve before merge |
| 🟠 | CRITICAL | Should resolve before merge |
| 🟡 | MAJOR | Important, worth addressing |
| 🔵 | MINOR | Improvement opportunity |
| ⚪ | INFO | Observation, no action required |

BLOCKER and CRITICAL findings with a specific `file:line` reference are posted as inline comments. All others go into the top-level summary comment.

---

## Notes

- This skill is council-scoped. It is designed for use with the Watch Council agent configuration.
- `OBSIDIAN_VAULT` must be set (via `.claude/settings.json`) for vault writes to work.
- `detect-platform.sh` must succeed before any other step is attempted.
- The skill does not modify any code. It is review-only by design.
