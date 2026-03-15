---
name: obsidian-digest
description: Synthesise multiple Obsidian session notes into a structured digest and optional Marp slide deck. Use when asked to summarise a week's work, produce a sprint review, create a presentation, or generate slides from session notes. Scope by topic, feature, project, or date range.
allowed-tools: Bash, Read
---

## Purpose

Read a collection of session notes from the Obsidian vault, synthesise them into a coherent digest, and optionally produce a Marp slide deck. Output quality and tone adapts to the intended audience. This is not a summary of a single session — it is a synthesis across multiple sessions, surfacing patterns, decisions, and progress that only become visible in aggregate.

---

## Prerequisites check

Before doing anything else, verify Marp is available if slides are requested:

```bash
npx @marp-team/marp-cli --version 2>/dev/null || echo "marp-not-found"
```

If `marp-not-found` and the user wants slides, show setup instructions:

> **Marp is not installed.** To enable slide generation, install it one of these ways:
>
> **Option A — VS Code extension (recommended for previewing):**
> Install "Marp for VS Code" from the VS Code marketplace: `ext install marp-team.marp-vscode`
>
> **Option B — CLI (required for PDF/PPTX export):**
> ```bash
> npm install -g @marp-team/marp-cli
> ```
> Or without global install (npx, no setup needed):
> ```bash
> npx @marp-team/marp-cli input.md -o output.html
> ```
>
> **You can proceed with the digest note now and generate slides later once Marp is available.**

---

## Step 1 — Gather inputs

Ask the following, presenting what you've inferred first. Ask all at once — do not spread across multiple turns.

Run to get context before asking:
```bash
git branch --show-current 2>/dev/null || echo "no-branch"
git rev-parse --show-toplevel 2>/dev/null || echo "no-repo"
date +"%Y-%m-%d"
```

Present inferred values and ask for corrections:

> **Before I generate the digest, confirm or adjust these:**
>
> - **Scope:** `<inferred from branch/repo, e.g. "emerald-grove-pet-clinic" or "all active work">` — what work to include (project name, feature, topic, or "all")
> - **Date range:** `<last 7 days by default, show actual dates>` — adjust if needed
> - **Audience:** `<infer from context — personal / team / leadership / client-facing>` — affects tone and detail
> - **Output:** `digest note only` / `digest + slides` / `slides only`
>
> Correct anything that's wrong, or press Enter to continue.

---

## Step 2 — Find matching session notes

Use the obsidian-cli if available, otherwise fall back to bash:

```bash
# Primary: obsidian-cli search
obsidian search query="type:session date:>=<start-date>" 2>/dev/null

# Fallback: direct file search
find "${OBSIDIAN_VAULT}/AI Sessions" -name "*.md" -newer /tmp/digest-start-date 2>/dev/null | sort
```

To filter by scope (project or topic), also run:
```bash
grep -rl "<scope>" "${OBSIDIAN_VAULT}/AI Sessions" --include="*.md" 2>/dev/null
```

Read each matching file. If no files are found, tell the user clearly:
> No session notes found matching scope `<scope>` between `<start>` and `<end>`. Check that sessions were saved with `/obsidian-summary` during this period.

Show a summary of what was found before proceeding:
> Found `<n>` session notes:
> - `<filename>` — `<one-line description from "What We Were Doing">`
> - ...
> Continue? (y / adjust scope / n)

---

## Step 3 — Synthesise

Read all matched notes in full. Produce a synthesis that surfaces what is only visible across multiple sessions — not a list of per-session summaries. Look for:

- **Patterns**: decisions that recurred, problems that reappeared, themes across sessions
- **Progress arc**: where things started, where they ended, what's still open
- **Key decisions**: the choices that shaped the work, especially ones with alternatives considered
- **Blockers and resolutions**: things that slowed work and how they were resolved
- **Outstanding risks**: anything flagged by agents or left in open questions across sessions
- **What shipped**: concrete deliverables, commits, PRs, merged work

Adjust depth and tone by audience:

| Audience | Tone | Technical depth | Agent findings | Commit refs |
|----------|------|----------------|---------------|-------------|
| Personal | Casual, Discworld-ok | Full | Include | Include |
| Team | Professional, clear | Full | Include summarised | Include |
| Leadership | Polished, outcome-focused | Outcomes only | Omit | Omit |
| Client-facing | Polished, precise, no jargon | Outcomes + key decisions | Omit | Omit |

---

## Step 4 — Generate the digest note

```markdown
---
type: digest
project: <project or topic>
period-start: <YYYY-MM-DD>
period-end: <YYYY-MM-DD>
audience: <personal|team|leadership|client-facing>
date: <YYYY-MM-DD>
tags:
  - claude-code
  - digest
  - <project>
sessions:
  - <[[wikilink to each source session note]]>
status: complete
---

# <Project or Topic> — <Period> Digest

> [!note] Summary
> <2–3 sentence executive summary of the period. What was the goal, what was achieved, what's next.>

## What Shipped
<Concrete deliverables. PRs merged, features completed, specs validated. Be specific — names, numbers, outcomes.>

%%For leadership/client: focus on outcomes and value, not implementation%%
%%For team/personal: include PR numbers, commit refs, spec numbers%%

## Key Decisions

> [!important] Decisions That Shaped This Work
> <One-line summary of the most consequential decision.>

| Decision | Reasoning | Impact |
|----------|-----------|--------|
| | | |

%%Link to [[decision notes]] in vault where they exist%%

## Progress Against Goals

%%Use task syntax to show state at end of period%%
- [x] Completed goal
- [~] In-progress goal
- [ ] Not reached goal

## What Slowed Us Down
<Blockers encountered and how they were resolved. Omit if nothing significant. For client-facing, reframe as "Challenges and Resolutions".>

> [!warning] Outstanding Risk
> <Any risk that was flagged and not yet resolved. Omit section if none.>

## Open Questions Going Forward
- [ ] <Question that spans into next period>

%%Omit for leadership/client unless strategically relevant%%

## Agent Findings (This Period)
%%Omit for leadership and client-facing audiences%%
%%Include for personal and team — one subsection per agent that had significant findings%%

### [[watch-<n>]]
- Finding

## Diagrams
%%Include if the period's work had a flow or architecture worth showing%%
%%See diagram guidance in obsidian-summary skill%%

## Source Sessions
%%Dataview-style reference list%%
- [[<session wikilink>]] — <one line>
```

---

## Step 5 — Generate Marp slides (if requested)

Produce a separate `.md` file with Marp frontmatter. Slide content is derived from the digest — not generated independently.

Slide density by audience:
- **Personal / team**: 6–10 slides, can include detail
- **Leadership / client-facing**: 5–7 slides maximum, outcomes and visuals only, no jargon

```markdown
---
marp: true
theme: default
paginate: true
footer: <project> · <period>
---

<!-- Slide 1: Title -->
# <Project or Topic>
## <Period>
<audience label if relevant>

---

<!-- Slide 2: Summary -->
# What We Did
<3–4 bullet points from "What Shipped" — outcomes, not tasks>

---

<!-- Slide 3: Key Decisions -->
# Decisions Made
%%Use a simple two-column table or bullet list%%
%%For leadership: outcome of decision only, not the alternatives%%

---

<!-- Slide 4: Progress -->
# Where Things Stand
%%Visual task list or simple before/after%%

---

<!-- Slide 5: Risks / Open Questions -->
# What's Still Open
%%Only include if genuinely relevant — omit slide entirely if nothing material%%

---

<!-- Final slide -->
# Next Steps
<Concrete actions going into the next period>
```

Add or remove slides based on content. Do not pad with empty slides. For Mermaid diagrams in slides, use a fenced mermaid block — Marp renders these natively.

---

## Step 6 — Confirm before writing

Show the digest note and (if requested) the slide deck. Ask:
> **Ready to write?**
> - Digest note → `Digests/<project>/<date>-digest.md`
> - Slides → `Digests/<project>/<date>-slides.md`
>
> (`y` to confirm, `e` to edit, `n` to cancel)

---

## Step 7 — Write to vault

```bash
bash ~/.claude/skills/obsidian-summary/write-to-vault.sh "<project>" "<date>-digest" "<date>" "Digests"
```

For slides, write the Marp file directly:
```bash
cat <<'SLIDES' > "${OBSIDIAN_VAULT}/Digests/<project>/<date>-slides.md"
<slide content>
SLIDES
```

To export slides to HTML or PDF (if Marp CLI is available):
```bash
# HTML (shareable, no dependencies)
npx @marp-team/marp-cli "${OBSIDIAN_VAULT}/Digests/<project>/<date>-slides.md" \
  -o "${OBSIDIAN_VAULT}/Digests/<project>/<date>-slides.html"

# PDF
npx @marp-team/marp-cli "${OBSIDIAN_VAULT}/Digests/<project>/<date>-slides.md" \
  --pdf -o "${OBSIDIAN_VAULT}/Digests/<project>/<date>-slides.pdf"
```

Ask before exporting: not everyone wants additional files generated by default.

---

## Step 8 — Confirm success

> ✓ Digest saved to `Digests/<project>/<date>-digest.md`
> ✓ Slides saved to `Digests/<project>/<date>-slides.md`
>
> To preview slides: open the `.md` file in VS Code with the Marp extension active, or run:
> ```bash
> npx @marp-team/marp-cli --preview "${OBSIDIAN_VAULT}/Digests/<project>/<date>-slides.md"
> ```
