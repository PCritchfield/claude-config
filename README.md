# claude-config

Version-controlled backup of the hand-maintained files that live in `~/.claude/`. This repository exists so those files are not lost when a machine changes, and so there is a clear record of what changed and why.

---

## What lives here

```
claude/.claude/
├── CLAUDE.md           # Global personality + Watch Council charter + SDD workflow
├── settings.json       # Claude Code settings: model, permissions, env vars, spinners
├── agents/             # Watch Council agent definitions (10 agents)
├── commands/           # Empty — SDD commands come from an external package
└── skills/             # Hand-maintained skills (not symlinked from external packages)
    ├── obsidian-summary/
    └── review/
```

The files are stored under `claude/.claude/` rather than directly at the repo root so the repository can hold other things (this README, for instance) without polluting the Claude config directory.

---

## Installing

These files are meant to live at `~/.claude/`. The simplest approach is a symlink:

```bash
ln -s /path/to/this/repo/claude/.claude ~/.claude
```

Or copy the files manually if you prefer not to symlink.

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

Ten specialised subagent reviewers, named after characters from Terry Pratchett's Discworld. Each agent has a defined domain, a set of skills, and clear rules about when they may write versus when they are review-only.

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
| `watch-nobby` | PR/MR diff analysis — reads the actual diff, categorises changes, summons the right council agents |

Three agents hold domain veto (Angua, Vimes, Granny) in that priority order. The full charter, including conflict resolution rules and the promotion path from Plan Mode to implementation, is in `CLAUDE.md`.

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

## commands/

Empty. SDD stage commands (`/SDD-1-generate-spec` through `/SDD-4-validate-spec-implementation`) are provided by the [spec-driven-workflow](https://github.com/liatrio-labs/spec-driven-workflow) package and symlinked into `~/.claude/commands/` from there. They are not duplicated here.
