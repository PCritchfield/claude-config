---
name: over-engineering-audit
description: Use when asked to audit a whole repository for over-engineering, bloat, or "context-gap" cruft (generator scaffolding, dead exports, droppable deps, delegating wrappers, defensive boilerplate) — the complexity that accumulates even in disciplined repos. Dispatches watch-granny and watch-carrot with a seam-aware lens that protects intentional architecture. Whole-repo scope; for diff/PR-scoped review use /review, and for apply-mode simplification of a diff use /simplify.
---

# /over-engineering-audit — Whole-Repo Council Audit

## Overview

This skill runs a **whole-repo** over-engineering audit through the Watch Council. It dispatches **watch-granny** (architecture altitude — is this abstraction intentional?) and **watch-carrot** (simplification — concrete cuts with `file:line`) in parallel, read-only, using a seam-aware prompt that **protects documented intentional abstractions from deletion**. It then synthesises ranked, tagged findings and lists the seams it protected so the reasoning is auditable.

Scope is **over-engineering and bloat only**. Correctness bugs, security holes, and performance are explicitly out of scope — route those through `/review` (diff) or the relevant specialist.

Complementary skills:
- **`/review`** — diff/PR-scoped council review across all domains.
- **`/simplify`** — built-in; apply-mode simplification of the current diff.
- **this skill** — whole-repo, over-engineering-only, findings-only (no auto-apply).

Rincewind stays out of it once dispatched. This is council business.

> Lens and taxonomy adapted from [ponytail](https://github.com/DietrichGebert/ponytail) by DietrichGebert (MIT). We copied the ~prompt, not the machinery.

---

## Step 1 — Determine the target repo

Default to the current repo root:

```bash
git rev-parse --show-toplevel 2>/dev/null || echo "no-repo"
```

If the user named a different path, use that. If no repo is detected and none was given, ask for a path and stop.

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

## Step 2 — Dispatch Granny and Carrot in parallel (read-only)

Send both agents, in a single message, the **identical prompt** below (substitute the repo path). Both are read-only — they must not edit, write, or run state-mutating commands. Their over-engineering lens lives in their agent definitions; this prompt invokes it with explicit scope.

```
READ-ONLY over-engineering audit of the repo at <REPO_ROOT>. Produce findings only —
do NOT edit or write files, and do not run any state-mutating command. Read/grep/glob only.

Apply your Over-Engineering Review Lens (the ladder, the seam-awareness cascade, the tag
taxonomy, and the lazy-not-negligent guard).

MANDATORY FIRST STEP — run the seam-awareness cascade before flagging ANY abstraction:
  (a) ARCHITECTURE.md  (b) CLAUDE.md / AGENTS.md  (c) inline // seam: markers or
  "seam discipline" docstrings  (d) no evidence → report at INFO with "confirm intent",
  NEVER a confident delete:/yagni:. An abstraction documented at (a)/(b)/(c) is PROTECTED.

SCOPE: over-engineering and bloat ONLY. Do NOT report correctness bugs, security holes,
or performance here.

OUTPUT:
1. Ranked findings, biggest cut first, one line each:  <tag> <what to cut>. <replacement>. [file:line]
   Tags: delete: / stdlib: / native: / yagni: / shrink:
2. A conclusion line: estimated net lines removable + dependencies droppable, or exactly
   "Lean already. Ship." if there is no removable overhead.
3. A separate list of every abstraction you assessed and PROTECTED, with the cascade rung
   that protected it — so the reasoning is auditable.

Focus on real bloat: generator/scaffolding residue, dead exports, unused dependencies,
wrappers that only delegate, dead feature flags, duplicated logic. Keep it tight —
paths and one-liners, not essays.
```

Granny works the architecture altitude (on-disk waste, structural bloat, is-this-seam-intentional); Carrot works the code altitude (dead exports, delegating wrappers, dep hygiene, `file:line` cuts). They tile complementary ground — **run both, always.** Do not substitute one for the other.

---

## Step 3 — Synthesise

Merge the two agents' output into one report:

1. **Findings** — de-duplicate, then rank biggest-cut-first across both agents. Preserve each finding's tag and `file:line`.
2. **Protected seams** — the union of what both agents protected, each with its cascade rung. This is the safety audit trail; never drop it.
3. **Conclusion** — combined estimate of net lines removable + dependencies droppable. If both said "Lean already. Ship.", say exactly that.
4. **Cascade coverage** — which rungs the repo had (from Step 1), and — if bare — the explicit caveat that single-impl abstractions were held at INFO.

Present findings only. **This skill does not apply fixes.** If the user wants cuts applied, that is a separate, promoted implementation step (Carrot may apply at IMPLEMENT stage; Granny remains review-only).

---

## Step 4 — Offer to save to Obsidian

Over-engineering findings are a natural investigation note. Offer:

```
Audit complete. Save findings to Obsidian? [y/n]
```

On yes, invoke `obsidian-summary` as an **investigation** note (subject = "over-engineering audit of <project>", outcome = findings). Otherwise keep it in-session.

---

## Step 5 — Surface deferred cuts as tech debt (optional)

Per the post-implementation rule, any "worth doing but not now" finding should become a tracked GitHub issue rather than evaporate:

```
Some findings are worth deferring. File them as GitHub issues? [y/n]
```

On yes, create one issue per deferred finding with the tag, the `file:line`, and the proposed cut. Tag appropriately (e.g. `tech-debt`, `over-engineering`).

---

## Notes

- **Findings-only by design.** No auto-apply, no PR posting (that's `/review`'s job).
- **Over-engineering only.** Correctness, security, and performance are out of scope — the seam cascade and the lazy-not-negligent guard exist precisely so this skill never recommends damaging good architecture or removing safety code.
- **Council-scoped.** Requires the Watch Council agent configuration (watch-granny, watch-carrot).
- `OBSIDIAN_VAULT` must be set (via `.claude/settings.json`) for the optional vault write.
