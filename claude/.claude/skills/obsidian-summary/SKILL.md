---
name: obsidian-summary
description: Save a structured summary of the current session to the Obsidian vault. Use when asked to save, log, or summarise to Obsidian, when writing a doc or reference note, when capturing a decision or ADR, or when context is getting long. Produces Obsidian-flavoured markdown with wikilinks, callouts, frontmatter, and Dataview-compatible properties.
allowed-tools: Bash, Read
---

## Purpose

Produce a well-structured Obsidian note from the current session and write it to the vault. The output must be useful out of context — readable weeks later by someone (including you) who wasn't in the session.

All output uses Obsidian-flavoured markdown: YAML frontmatter with Dataview-compatible properties, `[[wikilinks]]` for internal vault links, `> [!type]` callouts for highlighted information, and Mermaid diagrams where structure warrants it.

---

## Step 1 — Infer the note type

Before deriving paths or generating content, determine what kind of note this session calls for. Show the inferred type and confirm before proceeding.

| Type | When to use | Default location |
|------|-------------|-----------------|
| `session` | General work summary, branch progress, task completion | `AI Sessions/<project>/<label>/` |
| `document` | Standalone reference meant to be read on its own (how-to, explainer, overview) | `Docs/<project>/` |
| `decision` | A specific architectural or technical decision with context and rationale (ADR) | `Decisions/<project>/` |
| `investigation` | Exploration or research without implementation — findings and open questions | `Investigations/<project>/` |

Infer the type from:
- What the user asked for ("write a doc", "save what we decided", "summarise the session", "document how X works")
- The nature of the content in the session
- Whether the output is meant to be a reference (document/decision) or a record of work (session/investigation)

Show the inferred type as:
> `→ Note type: <type>` — <one sentence explaining why>
> Type a different type to override, or press Enter to continue.

---

## Step 2 — Derive the vault path

Run:
```bash
git branch --show-current 2>/dev/null || echo "no-branch"
git rev-parse --show-toplevel 2>/dev/null || echo "no-repo"
```

**Project name:** Take the final component of the repo root path (e.g. `emerald-grove-pet-clinic`). Ambiguous if: no repo detected, root is a workspace containing multiple sub-projects, or name is generic (`projects`, `src`, `workspace`).

**Session label:** Strip branch prefixes (`feature/`, `fix/`, `chore/`, `bugfix/`, `hotfix/`). Preserve ticket patterns (`PROJ-123`, `issue_1`). Ambiguous if: branch is `main`/`master`/`develop`, very short (`wip`, `test`, `temp`), or absent. For `document`, `decision`, and `investigation` types, derive the label from the subject matter rather than the branch name.

**Filename:** 
- `session` → `<YYYY-MM-DD>-session.md`
- `document` → `<slugified-title>.md`
- `decision` → `<YYYY-MM-DD>-<slugified-title>.md`
- `investigation` → `<YYYY-MM-DD>-<slugified-subject>.md`

Show the proposed full path:
> `→ Proposed path: <location>/<project>/<label>/<filename>`

Ask only about components that are genuinely ambiguous — one question at a time, project before label. Clean descriptive branches proceed silently.

---

## Step 3 — Generate the note

Use the template for the inferred type. Apply Obsidian-flavoured markdown throughout:

- Use `[[wikilinks]]` when referencing other notes that likely exist in the vault (agents by name, specs by number, previous sessions by label)
- Use `> [!type]` callouts for decisions, risks, warnings, and tips — choose the type that fits: `note`, `tip`, `warning`, `important`, `danger`, `question`
- Use Dataview-compatible frontmatter properties (typed: dates as `YYYY-MM-DD`, arrays as YAML lists)
- Use `%%hidden comments%%` for internal notes not meant for reading view
- Use `- [x]` / `- [ ]` task syntax for status tracking

---

### Template: session

```markdown
---
type: session
project: <project>
branch: <full branch name>
label: <label>
date: <YYYY-MM-DD>
tags:
  - claude-code
  - <project>
agents:
  - <list of Watch Council agents invoked, or empty>
sdd-spec: <spec number if applicable, e.g. "08", or omit>
status: complete
---

# <label> — <YYYY-MM-DD>

## What We Were Doing
One or two sentences. The task or problem, framed for someone reading cold.

## Decisions Made

> [!important] Key Decisions
> Brief one-line summary of the most important decision(s).

| Decision | Reasoning | Alternatives Considered |
|----------|-----------|------------------------|
| | | |

%%Omit this section if no explicit decisions were made%%

## Agent Findings
%%Omit entirely if no Watch Council agents were invoked%%

### [[watch-<name>]]
- Finding

> [!warning] <agent name>: <risk title>
> Use for any finding flagged as a risk or blocker.

## Task Status
- [x] Completed task
- [~] In-progress task  
- [ ] Not started

## Open Questions
%%Only include unresolved questions — things that came up but weren't answered%%
- [ ] Question

> [!question] Needs Decision
> Use for anything that explicitly requires Phil's input before work can continue.

## Next Steps
%%Only concrete actions identified in this session — not aspirational%%
- [ ] Step

## Diagrams
%%Include only if the session involved non-obvious flows, state machines, or cross-component interactions%%
%%See diagram guidance below%%

## Context at Save
- **Context fill:** <%>
- **Files touched:** 
- **SDD artifacts:** 
- **Commits:** 
```

---

### Template: document

```markdown
---
type: document
project: <project>
date: <YYYY-MM-DD>
tags:
  - claude-code
  - <project>
  - reference
aliases:
  - <alternative title if useful>
status: draft
---

# <Title>

> [!note] About This Document
> One sentence on what this is and who it's for.

## Overview
<Purpose and scope>

## <Section>
<Content — use wikilinks to related notes, callouts for important asides>

## Related
- [[<related note>]]
```

---

### Template: decision

```markdown
---
type: decision
project: <project>
date: <YYYY-MM-DD>
tags:
  - claude-code
  - <project>
  - adr
status: accepted
---

# Decision: <Title>

## Context
What situation or problem prompted this decision.

## Decision
What was decided, stated plainly.

> [!important] Summary
> One-sentence version of the decision for scanning.

## Reasoning
Why this option over alternatives.

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| | |

## Consequences
What this decision makes easier, harder, or precludes.

> [!warning] Trade-offs
> Anything worth flagging as a known downside.

## Related
- [[<related spec or session>]]
```

---

### Template: investigation

```markdown
---
type: investigation
project: <project>
date: <YYYY-MM-DD>
tags:
  - claude-code
  - <project>
  - investigation
subject: <what was investigated>
outcome: <inconclusive | findings | abandoned>
---

# Investigation: <Subject>

## What We Were Looking At
One or two sentences on the question or area being explored.

## Findings

> [!tip] Key Finding
> The most important thing learned.

<Findings in prose or bullets — be specific>

## What We Didn't Explore
Things that were adjacent but out of scope for this session.

## Open Questions
- [ ] Question

## Next Steps
- [ ] Step, or "None — investigation complete" if finished
```

---

## Diagram guidance

Generate a Mermaid diagram if the session involved something with structure that prose can't convey cleanly. Place under `## Diagrams` (in session/investigation) or inline where relevant (in document/decision).

**Use a diagram when the session involved:**
- A multi-step flow across components → `sequenceDiagram` or `flowchart`
- State or status transitions → `stateDiagram-v2`
- Decision branching logic → `flowchart TD`
- Data model or entity relationships → `erDiagram`
- Pipeline or dependency ordering → `flowchart LR`

**Skip a diagram when:**
- The session was a linear fix with no branching
- The decisions table already shows the structure clearly
- You would be inventing structure not present in the session

Format:
````markdown
```mermaid
<diagram>
```
> <One sentence: what this shows and why it's worth having.>
````

One well-chosen diagram is better than three redundant ones. For decision notes, link Mermaid nodes to vault notes where relevant using Obsidian's `class NodeName internal-link` syntax.

---

## Step 4 — Confirm before writing

Show the full generated note and ask:
> **Ready to write?** (`y` to confirm, `e` to edit first, `n` to cancel)

Do not write anything until confirmed.

---

## Step 5 — Write to vault

```bash
bash ~/.claude/skills/obsidian-summary/write-to-vault.sh "<project>" "<label>" "<date>"
```

Pass the full markdown content via stdin. If the script fails, show the error and offer to print the markdown to the terminal for manual saving.

---

## Step 6 — Confirm and link

Report the path written to using the script's stdout output:
> ✓ Saved to `<path from script>`

If this session references a previous session or spec that likely exists in the vault, suggest the wikilink:
> 💡 You may want to add `[[<previous session label>]]` to link this note to the previous session on this branch.

---

## Context monitoring

At 75%+ context fill, suggest this skill as Rincewind — panicked, urgent, brief:
> *HAT FLOP* Boss, the narrative is at approximately `<X>`% and I strongly recommend we save something to the Stone Ledger before context compaction takes the good bits. Shall I?

When invoked manually, skip the preamble and go straight to Step 1.
