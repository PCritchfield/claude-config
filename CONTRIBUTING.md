# Contributing

This repo is a Claude Code configuration *and* the reference implementation of a
method for building agent systems. Changes are welcome; the bar is that the repo
must keep practising what it documents.

## Read this first: the repo is your live config

`install.sh` uses GNU stow, so `~/.claude/agents`, `skills`, `rules`, `hooks`,
`CLAUDE.md` and `statusline.sh` are **symlinks into this working tree** — not
copies, and not into git objects.

Two consequences that surprise everyone once:

1. **Editing a file here changes agent behaviour immediately.** No install step.
2. **`git checkout`, `stash`, `rebase` and `bisect` rewrite your live config.**
   Switching to a branch without a fix reverts that fix in the running agent.

If you are working on agent definitions, expect your Claude to change under you
as you move between branches. That is the design, not a bug — but know it before
you go looking for ghosts.

`settings.json` is the one that breaks. `install.sh` *does* stow it — but Claude
Code and its tools (`/config`, `/doctor`, `/permissions`, the desktop app) save
it by writing a new file and renaming it over the old one. That replaces the
symlink with a regular file. From then on the repo copy is a stale snapshot and
nothing tells you.

Directories are immune: a tool writing a file *inside* a symlinked directory
does its rename inside the repo. That is why `agents/`, `skills/`, `rules/` and
`hooks/` keep working. Single-file symlinks — `settings.json`, and in principle
`CLAUDE.md` and `statusline.sh` — survive only for as long as nothing rewrites
them that way.

So `settings.json` is **not stowed**. It is listed in `claude/.stow-local-ignore`,
and git does the syncing instead:

| Direction | When | How |
|---|---|---|
| live → repo | every session end | `SessionEnd` hook runs `sync-settings.py capture` |
| repo → live | after `git pull` | `.githooks/post-merge` runs `sync-settings.py apply --post-merge` |

- **The live file is authoritative.** Edit `~/.claude/settings.json` (or use
  `/config`), not the repo copy. Your change lands in `git status` at session end.
- **Capture never commits.** You review the diff and commit when you choose.
- **Keys are sorted on every write**, so a tool reordering keys no longer shows up
  as a rewrite in `git diff`. Only real changes do.
- **Capture refuses secrets.** Any env var whose name looks like a token, key or
  password — or whose value looks like one — blocks the capture. This repo is public.
- **Apply refuses to clobber.** After a pull it acts only if `settings.json`
  changed, and if this machine has live changes that were never captured, it
  stops and tells you instead of overwriting them. It always backs up first.

Run `./verify-drift.sh` to confirm every link is intact and `settings.json` is in
sync.

Known limit: hook commands with absolute paths (`~/.config/iterm2/cc-status`, the
herdr hook) are machine-specific but are synced verbatim. On a machine without
those scripts they will fail harmlessly. A machine-local overlay would fix this,
but user-level `settings.local.json` support is unconfirmed, so it is not relied on.

## Setup

```bash
brew install stow          # macOS
./install.sh               # stow symlinks into ~/.claude
./install_skills.sh        # community skills from skills.txt
```

The obra/superpowers plugin is a prerequisite — it provides
`systematic-debugging`, `test-driven-development`, `verification-before-completion`,
`requesting-code-review`, `finishing-a-development-branch` and `writing-skills`.
Install it via `/plugins` in Claude Code before running `install_skills.sh`.

## Before you open a PR

```bash
scripts/validate-config.py          # agent/settings schema — gates CI
scripts/validate-config.py --strict # ignore the baseline, see all debt
./verify-drift.sh                   # local: does ~/.claude match this repo?
```

`validate-config.py` is stdlib-only and runs anywhere Python 3 does.

### The baseline ratchet

`scripts/validate-config-baseline.json` records violations that already exist.
They are reported as warnings so CI is green on known debt while still failing
on anything **new**.

- **Do not add entries to it** to make your PR pass. If the validator flags your
  change, fix the change.
- **Do remove entries** as you fix the underlying problems. The validator tells
  you which baselined violations no longer reproduce.
- An empty baseline means the debt is cleared. That is the goal.

Regenerate deliberately, never casually: `scripts/validate-config.py --update-baseline`.

## Output gates

Every PR carries four sections, from
[`rules/council-charter.md`](claude/.claude/rules/council-charter.md): **Verification**,
**Rollback**, **Risks and assumptions**, **Scope control**. The PR template
prompts for all four. Write "n/a" with a reason rather than deleting one.

An honest "verification did not complete, here is what remains" is worth more
than an implied pass. Two of the three defects that motivated this CI survived
four months precisely because documentation asserted things nobody checked.

## Adding an agent

Agent definitions live in `claude/.claude/agents/`. Frontmatter:

```yaml
---
name: watch-example          # must match the filename
description: >
  One or two sentences on what this agent is for.
  Aliases: example, thing
model: sonnet                # or opus
permissionMode: plan         # default | plan | acceptEdits | auto | dontAsk | bypassPermissions
isolation: worktree          # only if the agent writes code
tools: Read, Grep, Glob, Bash
skills:
  - some-skill-name
---
```

Two rules the validator enforces:

- **Skills go in `skills:`, never in `tools:`.** `tools:` accepts only built-in
  tool names. A skill listed there silently never loads — this was defect 2, and
  it made the entire capability layer inert for months.
- **`skills:` entries must resolve** to a directory in `claude/.claude/skills/`,
  a declaration in `skills.txt`, or the superpowers plugin set.

And one rule the validator warns about:

- **Do not deny `Write`/`Edit` on an agent whose body claims edit rights.**
  `disallowedTools` is static and wins; no prompt can lift it. If an agent should
  write, give it `Write`, `Edit` and `isolation: worktree` — safety comes from
  isolation, not from permission denial.

## Adding a skill

Custom skills are real directories under `claude/.claude/skills/` and are
tracked. Community skills are declared in `skills.txt` and installed as symlinks
by `install_skills.sh`; they are gitignored by name. Do not commit a community
skill's contents.

`claude/.claude/skills/synced/` is written by the Claude desktop app and is
gitignored. Never commit it.

## Commits

Conventional commits. Explain *why* in the body — this repo's history is part of
its documentation, and a commit that only says what changed is a commit that has
to be re-derived later.
