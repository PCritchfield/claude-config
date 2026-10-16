---
name: over-engineering-audit
description: Use when asked to audit a whole repository for over-engineering, bloat, or "context-gap" cruft (generator scaffolding, dead exports, droppable deps, delegating wrappers, defensive boilerplate) — the complexity that accumulates even in disciplined repos. Dispatches crew:architecture and crew:coder with a seam-aware lens that protects intentional architecture. Whole-repo scope; for diff/PR-scoped review use crew:review, and for apply-mode simplification of a diff use /simplify.
---

# /over-engineering-audit — Whole-Repo Audit

## Overview

This skill runs a **whole-repo** over-engineering audit with the crew. It dispatches **crew:architecture** (architecture altitude — is this abstraction intentional?) and **crew:coder** (simplification — concrete cuts with `file:line`) in parallel, read-only, using a seam-aware prompt that **protects documented intentional abstractions from deletion**. It then synthesises ranked, tagged findings and lists the seams it protected so the reasoning is auditable.

Scope is **over-engineering and bloat only**. Correctness bugs, security holes, and performance are explicitly out of scope — route those through `crew:review` (diff) or the relevant specialist.

Complementary skills:
- **`crew:review`** — diff/PR-scoped guardian review across all domains.
- **`/simplify`** — built-in; apply-mode simplification of the current diff.
- **this skill** — whole-repo, over-engineering-only, findings-only (no auto-apply).

> Lens and taxonomy adapted from [ponytail](https://github.com/DietrichGebert/ponytail) by DietrichGebert (MIT). We copied the ~prompt, not the machinery.

---

## Step 1 — Determine the target repo

Default to the current repo root:

```bash
git rev-parse --show-toplevel 2>/dev/null || echo "no-repo"
```

The target must be this session's repo, because `crew:coder`'s worktree (Step 2) is made from it. If the user named a different path, ask them to run the skill from that repo and stop. If no repo is detected, say so and stop.

Record which **seam-awareness cascade rungs** the repo actually has — this calibrates confidence:

```bash
ROOT="<repo root>"
ls "$ROOT/ARCHITECTURE.md" "$ROOT/docs/architecture.md" 2>/dev/null   # rung (a)
ls "$ROOT/CLAUDE.md" "$ROOT/AGENTS.md" 2>/dev/null                     # rung (b)
grep -rIl -E '(//|#) ?seam:' "$ROOT" --include='*.*' 2>/dev/null | head   # rung (c)
```

> [!warning] Bare-repo limitation (known, not yet fully proven)
> On a repo with **none** of rungs (a)/(b)/(c), the only protection against a false-positive deletion of an *undocumented-but-intentional* abstraction is rung (d): downgrade to INFO + "confirm intent", never a confident `delete:`/`yagni:`. This safety default is proven on documented repos but only partially tested on bare ones. When the target has no cascade metadata, **say so in the report** and treat every single-implementation abstraction as INFO-only.

---

## Step 2 — Dispatch crew:architecture and crew:coder in parallel (read-only)

Send both agents, in a single message, the **identical prompt** below (substitute the repo path). Both are read-only — they must not edit, write, or run state-mutating commands. Dispatch `crew:coder` with `isolation: "worktree"`: it can write, so a stray edit lands in a throwaway worktree, not the user's checkout. That worktree holds `HEAD` only. `crew:architecture` has no write tools, so it reads `<REPO_ROOT>` directly, with no isolation. Crew agents carry no over-engineering lens of their own, so this prompt carries all of it, and its output format replaces theirs.

```
Whole-repo over-engineering audit. This is not a diff review: this prompt's OUTPUT
section replaces your usual Findings and VERDICT format. Do not return BLOCK.

READ-ONLY over-engineering audit of the repo at <REPO_ROOT> (if you were given a worktree,
audit your worktree: it is that repo at HEAD). Produce findings only —
do NOT edit or write files, and do not run any state-mutating command. Read/grep/glob only.

THE LADDER. For any code, ask in order; it is over-engineered if it lands lower than it
needs to: (1) does it need to exist at all? (2) is it already in this codebase?
(3) is it in the standard library? (4) is it a native platform/framework feature?
(5) is it an already-installed dependency? (6) could it be one line? (7) only then,
the minimum working code.

LAZY, NOT NEGLIGENT. Never recommend removing trust-boundary validation, error handling,
security checks, or accessibility, however redundant they look.

MANDATORY FIRST STEP — run the seam-awareness cascade before flagging ANY abstraction
(Protocol, ABC, interface, wrapper, base class, single-implementation indirection):
  (a) ARCHITECTURE.md  (b) CLAUDE.md / AGENTS.md  (c) inline // seam: markers or
  "seam discipline" docstrings  (d) no evidence → report at INFO with "confirm intent",
  NEVER a confident delete:/yagni:. An abstraction documented at (a)/(b)/(c) is PROTECTED.

SCOPE: over-engineering and bloat ONLY. Do NOT report correctness bugs, security holes,
or performance here.

OUTPUT:
1. Ranked findings, biggest cut first, one line each:  <tag> <what to cut>. <replacement>. [file:line]
   Tags: delete: dead, unused or speculative code / stdlib: hand-rolled logic the standard
   library covers / native: duplicates a platform or framework feature / yagni: speculative
   single-implementation abstraction or unused config, ONLY after the cascade clears it /
   shrink: duplicated logic that compresses. Rung (d) items are INFO with "confirm intent".
2. A conclusion line: estimated net lines removable + dependencies droppable, or exactly
   "Lean already. Ship." if there is no removable overhead.
3. A separate list of every abstraction you assessed and PROTECTED, with the cascade rung
   that protected it — so the reasoning is auditable.

Focus on real bloat: generator/scaffolding residue, dead exports, unused dependencies,
wrappers that only delegate, dead feature flags, duplicated logic. Keep it tight —
paths and one-liners, not essays.
```

`crew:architecture` works the architecture altitude (on-disk waste, structural bloat, is-this-seam-intentional); `crew:coder` works the code altitude (dead exports, delegating wrappers, dep hygiene, `file:line` cuts). They tile complementary ground — **run both, always.** Do not substitute one for the other.

---

## Step 3 — Synthesise

Merge the two agents' output into one report:

1. **Findings** — de-duplicate, then rank biggest-cut-first across both agents. Preserve each finding's tag and `file:line`.
2. **Protected seams** — the union of what both agents protected, each with its cascade rung. This is the safety audit trail; never drop it.
3. **Conclusion** — combined estimate of net lines removable + dependencies droppable. If both said "Lean already. Ship.", say exactly that.
4. **Cascade coverage** — which rungs the repo had (from Step 1), and — if bare — the explicit caveat that single-impl abstractions were held at INFO.
5. **Uncommitted work** — if `git status --porcelain` was not empty, say that `crew:coder` audited `HEAD` only, so its findings do not cover uncommitted changes.

Present findings only. **This skill does not apply fixes.** If the user wants cuts applied, that is a separate, promoted implementation step (dispatch `crew:coder` in Build mode with `isolation: "worktree"`; `crew:architecture` stays read-only).

---

## Step 4 — Offer to save to Obsidian

Over-engineering findings are a natural investigation note. Offer:

```
Audit complete. Save findings to Obsidian? [y/n]
```

On yes, invoke `obsidian-summary` as an **investigation** note (subject = "over-engineering audit of <project>", outcome = findings). Otherwise keep it in-session.

---

## Step 5 — Surface deferred cuts as tech debt (optional)

Any "worth doing but not now" finding should become a tracked GitHub issue rather than evaporate:

```
Some findings are worth deferring. File them as GitHub issues? [y/n]
```

On yes, create one issue per deferred finding with the tag, the `file:line`, and the proposed cut. Tag appropriately (e.g. `tech-debt`, `over-engineering`).

---

## Notes

- **Findings-only by design.** No auto-apply, no PR posting (that's `crew:review`'s job, when asked).
- **Over-engineering only.** Correctness, security, and performance are out of scope — the seam cascade and the lazy-not-negligent guard exist precisely so this skill never recommends damaging good architecture or removing safety code.
- **Crew-scoped.** Requires the `crew` plugin (crew:architecture, crew:coder).
- `OBSIDIAN_VAULT` must be set (via `.claude/settings.json`) for the optional vault write.
