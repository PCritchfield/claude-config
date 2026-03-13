# claude-config

Version-controlled backup of the hand-maintained files that live in `~/.claude/`. This repository exists so those files are not lost when a machine changes, and so there is a clear record of what changed and why.

---

## What lives here

```
claude/.claude/
├── CLAUDE.md           # Global personality + Watch Council charter + SDD workflow
├── settings.json       # Claude Code settings: model, permissions, env vars, spinners
├── agents/             # Watch Council agent definitions (12 agents)
├── commands/           # Empty — SDD commands come from an external package
└── skills/             # Hand-maintained skills (not symlinked from external packages)
    ├── obsidian-summary/
    └── review/
```

The files are stored under `claude/.claude/` rather than directly at the repo root so the repository can hold other things (this README, for instance) without polluting the Claude config directory.

---

## Installing

These files are meant to live at `~/.claude/`. The repo uses [GNU Stow](https://www.gnu.org/software/stow/) to symlink the `claude/` package into your home directory:

```bash
./install.sh
```

This runs `stow -R claude`, which creates symlinks from `~/.claude/` pointing into the repo. Requires `stow` (`brew install stow`).

Alternatively, copy the files manually if you prefer not to symlink.

**Before using on a new machine**, check `settings.json` for local absolute paths and update them:

- `OBSIDIAN_VAULT` — set to the vault location on this machine
- The path will be wrong on any machine other than the one it was written on

---

## CLAUDE.md

The main configuration file. It contains three sections:

**Rincewind persona** — Claude's global personality: a deeply reluctant wizard who is always helpful in spite of himself. Tracks two independent scales (context fill and emotional heat from the user) that affect how he behaves. Pure flavour, but it shapes every interaction.

**Watch Council charter** — The governance rules for a system of specialised subagent reviewers. Defines which agents exist, what domains they own, who holds veto authority, how conflicts are resolved, and how a session moves from Plan Mode to implementation. This is the part that actually affects how code work gets done.

**SDD workflow** — Instructions for using the [Spec-Driven Development workflow](https://github.com/liatrio-labs/spec-driven-workflow). Stage commands, agent responsibilities within each stage, and how SDD-3 grants write permission without suspending the charter rules.

---

## The Watch Council

Twelve specialised subagent reviewers, named after characters from Terry Pratchett's Discworld. Each agent has a defined domain, a set of skills, and clear rules about when they may write versus when they are review-only.

| Agent | Domain |
|-------|--------|
| `watch-dispatch` | Routing and orchestration — assigns the right agents to a request |
| `watch-carrot` | General coding, tests, safe refactors |
| `watch-granny` | Architecture, long-term maintainability, data model design (holds veto) |
| `watch-angua` | Security, secrets, authn/authz, CVE hygiene (holds veto) |
| `watch-magrat` | Local DX, Docker/Compose, Taskfile/Makefile, devcontainers, onboarding |
| `watch-moist` | CI/CD, pipelines, caching, releases, delivery strategy |
| `watch-sybil` | Docs, PR text, commit messages, onboarding clarity, ADRs |
| `watch-vimes` | Database, schema migrations, query safety, data integrity (holds veto) |
| `watch-adorabelle` | UX/UI design, interface clarity, component design, accessibility |
| `watch-havelock` | IaC/cloud architecture review, cost, reliability, networking, K8s cluster design (holds veto) |
| `watch-drumknott` | IaC/cloud implementation — writes Terraform, Pulumi, CloudFormation, K8s manifests |
| `watch-nobby` | PR/MR diff analysis — reads the actual diff, categorises changes, summons the right council agents |

### Veto authority

Four agents hold domain veto. When their domains overlap, the following priority order resolves conflicts without escalation:

| Priority | Agent | Veto scope |
|----------|-------|------------|
| 1 | `watch-angua` | Security concerns override architectural and data concerns when the overlap involves credential exposure, auth bypass, or supply chain risk |
| 2 | `watch-vimes` | Data integrity concerns override architectural concerns when the overlap involves irreversible data operations, migration safety, or schema correctness under live traffic |
| 3 | `watch-havelock` | Cloud architecture concerns override application architecture when the overlap involves infrastructure fitness, cost, reliability, or networking topology |
| 4 | `watch-granny` | Application architecture concerns are authoritative in all other design and structure disputes |

Veto is deterministic, not a debate. The veto-holder states their ruling and the reason in one sentence. The overruled agent may file a **minority report** (what they'd do differently and why, in two sentences), which travels with the plan for the user to review. The full charter, including conflict resolution rules and the promotion path from Plan Mode to implementation, is in `CLAUDE.md`.

---

## skills/

Two hand-maintained skills. Skills installed via external packages (such as the SDD commands) are not tracked here — they are symlinked into `~/.claude/skills/` from their own repositories.

### obsidian-summary

Saves a structured session summary to an Obsidian vault. Supports four note types: `session`, `document`, `decision`, and `investigation`. Produces Obsidian-flavoured markdown with YAML frontmatter, wikilinks, and Dataview-compatible properties.

The vault path is read from the `OBSIDIAN_VAULT` environment variable set in `settings.json`. Rincewind is instructed to suggest this skill at 75%+ context fill, since context compaction loses decisions and findings that are worth keeping.

Files:
- `SKILL.md` — full skill definition
- `write-to-vault.sh` — writes the generated note to the correct vault path

### review

Orchestrates a full Watch Council PR/MR review. Detects the platform (GitHub or GitLab), fetches open PRs, applies ignore rules, routes the diff through `watch-nobby` for council assignment, writes the structured report to the Obsidian vault, and optionally posts findings back to the PR as inline and summary comments.

Files:
- `SKILL.md` — full skill definition and step-by-step process
- `detect-platform.sh` — detects whether the repo uses `gh` or `glab`
- `post-review.sh` — maps diff positions and posts comments to the PR/MR

---

## settings.json

Contains no secrets. Does contain:

- `model` — the default model (`opus[1m]`)
- `OBSIDIAN_VAULT` — absolute path to the Obsidian vault on this machine
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — enables the agent teams feature
- `permissions.deny` — blocks Claude from reading `.env*` files and `~/.ssh/**`
- `spinnerVerbs` — a large set of Discworld-themed loading messages, because why not

The `OBSIDIAN_VAULT` path will need updating on any machine other than the original.

---

## Design Decisions

This section explains *why* the system is structured the way it is. The what is in the sections above. The why is what makes it transferable.

### Personalities encode behavioural contracts

The Discworld theme is not decoration. Every agent has a defined character, and that character is doing real work.

A generic instruction like "always include a rollback plan" is easy to ignore under pressure. An agent whose defining personality trait is *"I have no patience for migrations without rollback scripts — none — I will say this every time"* is much harder to prompt away from that behaviour. The character is the constraint, made memorable and consistent.

This also makes the system auditable in a human way. If a plan comes back without a rollback script, you know Vimes wasn't consulted. If security concerns are being hedged rather than stated plainly, Angua wasn't in the room. The personas make gaps visible.

### Read-only by default

The system starts in Plan Mode every session. Nothing is written until you explicitly say so.

This is the most important structural decision in the whole setup. It forces a review step before any code changes land. It means you read the plan, you check the output gates, you understand what's about to happen — and *then* you promote. The promotion phrases ("You may implement.", "Proceed with wide changes.") are intentionally specific so they can't be triggered accidentally.

The alternative — agents that write on first instinct — produces fast output and frequent cleanup. This produces slower first output and fewer surprises.

### Veto authority is deterministic

Four agents hold domain veto: Angua (security), Vimes (data integrity), Havelock (cloud/IaC architecture), Granny (application architecture). When their domains overlap, the priority order is fixed: Angua > Vimes > Havelock > Granny.

The reason for deterministic resolution rather than debate is that agent debates produce noise and stall sessions. The veto-holder states their ruling in one sentence. The overruled agent files a two-sentence minority report. The plan proceeds. You have the dissenting view on record without burning time on a council argument.

The minority report matters. It's not a concession mechanism — it's an audit mechanism. Dissent is preserved, not suppressed.

### Opus for review-only agents, Sonnet for implementation agents

Angua, Vimes, Havelock, and Granny run on Opus. Every other agent runs on Sonnet.

The four veto-holders are never allowed to write code by default. Their value is depth of analysis, not speed of output. Opus costs more per token — that cost is justified when an agent is doing a deep security review or architectural critique, not when it's writing a README or a Makefile alias.

Implementation agents run on Sonnet because speed matters for code generation and the output can be reviewed before it lands. The model allocation and the write permissions are designed together: the expensive, careful model reviews; the faster model implements.

### Justification-per-assignment, not a fixed agent cap

Earlier versions of this setup capped council sessions at three agents. That cap was a cost/noise heuristic that made sense at the time and stopped making sense when the goal shifted to thoroughness.

The current system has no fixed cap. Dispatch must justify each agent inclusion in one sentence. If an agent can't be justified in a sentence, they're not needed. A well-scoped task gets one agent. A cross-disciplinary task gets five. The justification requirement self-regulates without an arbitrary ceiling.

### Two utility agents, two different routing models

Dispatch and Nobby are both routing agents. They are not interchangeable.

**Dispatch** routes *requests*. It reads what you asked for, pattern-matches against domain keywords, and assigns the relevant specialists. It has no opinion about the work itself.

**Nobby** routes *evidence*. It reads the diff — not the PR description, the actual diff — categorises changed files by domain, and summons the relevant specialists based on what actually changed. A PR description can say anything. A diff doesn't lie.

The distinction matters for PR reviews specifically: you want the council's eyes on what *is* in the code, not on what someone claimed was in the code.

### SDD-3 as implicit promotion

The Spec-Driven Development workflow has an execution stage (`/SDD-3-manage-tasks`) that implies implementation. Requiring a separate promotion phrase after invoking SDD-3 is redundant friction — the decision to implement has already been made upstream.

SDD-3 grants IMPLEMENT (NARROW) automatically. All other charter rules — output gates, rollback requirements, veto authority — remain in full effect. SDD-3 grants write permission, not write impunity.

### Skills as the capability layer

Agents have personalities and domains. Skills give them specific procedural knowledge to act on those domains reliably.

Carrot knowing to use TDD is a personality trait. Having the `test-driven-development` skill means he has documented practice to follow, not just an instruction to obey. The distinction matters under pressure — when the task is complex and the temptation is to skip the test and just ship, the skill is what holds the line.

Skills are installed globally so they travel across projects. Each agent's file lists its skills with a "reach for this agent when..." trigger, so Rincewind knows not just *that* an agent has a capability but *when* that capability is the right one to invoke.

---

## The Transferable Pattern

The Watch Council is one implementation of a more general architecture. You do not need Discworld. You do not need ten agents. You need the structure.

### The pattern

```
┌─────────────────────────────────────────┐
│           Lead Agent                    │
│  Receives requests, owns the session,   │
│  collects findings, presents output     │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼──────┐  ┌──────▼──────┐
│  Dispatcher │  │Diff Reader  │
│  (requests) │  │  (reviews)  │
└──────┬──────┘  └──────┬──────┘
       │                │
       └───────┬────────┘
               │ assigns with justification
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐ ┌───▼───┐ ┌────▼──┐
│ Spec- │ │ Spec- │ │ Spec- │
│ialist │ │ialist │ │ialist │
│  + 🔴 │ │       │ │       │
│ veto  │ │       │ │       │
└───────┘ └───────┘ └───────┘
               │
    ┌──────────▼──────────┐
    │    Proof Artifacts  │
    │  (decisions, audit  │
    │   trail, context)   │
    └─────────────────────┘
```

### The five components

**1. A lead agent with a clear mandate**
One agent owns the session. It receives requests, decides what to do, collects output from specialists, and presents results. It does not do everything itself — it orchestrates.

The lead agent's personality (if it has one) should reflect the mandate: reluctant but thorough, confident and direct, whatever fits your working style. The key requirement is that it has a *consistent voice* so you always know what you're interacting with.

**2. A routing mechanism**
Something that maps requests to the right specialists without the lead agent having to make every routing decision. The simplest version is a single dispatcher with a routing decision tree. A more capable version adds a diff-reader for code review workflows.

The routing mechanism should justify its assignments. One sentence per agent. If it can't justify an inclusion, the agent isn't needed.

**3. Specialists with constrained domains**
Each specialist owns one domain and only one domain. They have clear rules about what they will and won't do, what triggers an escalation, and — crucially — what their output format looks like.

Constrained domains produce predictable output. Predictable output is how you keep AI on track.

Consider which specialists need veto authority in your domain. The veto hierarchy should be deterministic — no debates, no stalling.

**4. Skills as the capability layer**
Skills give specialists procedural knowledge to act on their domains reliably. A specialist that "knows about security" behaves differently from a specialist that has `security-best-practices` loaded — the skill provides documented practice to follow, not just an instruction to obey.

Install skills globally so they travel across projects. Define trigger conditions per agent so the lead agent knows when to lean on a capability, not just that it exists.

**5. A proof artifact mechanism**
Something that captures what happened, what was decided, and what was found — in a format that's readable out of context, weeks later, by someone who wasn't in the session.

This is the feedback loop that makes the system self-correcting over time. Without it, every session starts cold. With it, decisions compound.

### Adapting this for your own setup

A minimal version of this pattern is three files:

- `CLAUDE.md` — your lead agent persona + council charter + governance rules
- `agents/dispatch.md` — a routing agent with a decision tree for your domains
- `agents/specialist.md` — one specialist per domain you care about

You don't need ten specialists. Start with the domains that cause the most problems in your current workflow. Add agents when you find yourself repeatedly routing a type of request that doesn't fit the existing specialists.

You don't need a theme. The Watch Council uses Discworld because memorable characters make behavioural contracts stick. Your version can be named after anything, or nothing. What matters is that each agent has a *defined voice and explicit constraints*, not what you call it.

---

## commands/

Empty. SDD stage commands (`/SDD-1-generate-spec` through `/SDD-4-validate-spec-implementation`) are provided by the [spec-driven-workflow](https://github.com/liatrio-labs/spec-driven-workflow) package and symlinked into `~/.claude/commands/` from there. They are not duplicated here.
