# claude-workflow with the Watch Council

claude-workflow is an **internal Liatrio** Claude Code plugin for spec-driven
delivery (spec → plan → dispatch → validate → review). This repo enables it in
`settings.json`. Its source is not public and is not reproduced here; this
document covers only how it is used alongside the council and the operational
lessons learned.

Status: **under evaluation.** Nothing here is a final architecture decision.

## How the two fit

Working hypothesis: **claude-workflow orchestrates; the council supplies
expertise.** The council's lasting value is domain doctrine (security, data,
IaC, architecture), the veto order, Rincewind as operator, and CI as the gate.

Today the seam is the diff: claude-workflow runs its pipeline, then the council's
veto holders review the result through `/review` before merge. Deeper integration
depends on moving council doctrine into skills (phase 06).

## The worktree hook problem

Any plugin that registers a `WorktreeCreate` hook **replaces** Claude Code's own
worktree creation for every isolated agent — it cannot defer back to the default.
claude-workflow 4.4.1's hook is incompatible with the payload Claude Code sends
([documented here](https://code.claude.com/docs/en/hooks#worktreecreate-input):
the slug arrives as `name`), so with the plugin enabled every agent with
`isolation: worktree` — all six council writers — fails before starting.

A real payload, captured 2026-10-07, contained only `cwd`, `hook_event_name`,
`name`, `prompt_id`, `scratchpad_dir`, `session_id` and `transcript_path`.
**No `agent_id`**, despite the docs listing it as a common field: the hook fires
in the parent's context. The only signal that a worktree belongs to a subagent
is Claude Code's `agent-<hex>` slug — observed, not documented.

### The local fix

A small local patch to the plugin's hook makes it compatible. Because it contains
lines of the plugin's internal source, it is **kept outside this public repo**,
at `~/.claude/local-patches/claude-workflow-4.4.1-worktree-create.patch`
(override with `CLAUDE_LOCAL_PATCHES`). It is a fix for this environment, not
an upstream change.

```bash
scripts/apply-local-patches.sh          # re-apply after a plugin update (idempotent)
scripts/apply-local-patches.sh --check  # report only
./verify-drift.sh                       # includes the check
```

It applies only to the version it was written for; other versions are reported,
never patched by guesswork. A new machine needs the patch file copied into place
manually before `install.sh` can apply it.

## Known side effect: agent worktrees are not cleaned up

With the plugin's hook in charge, a finished agent's worktree and its branch are
not removed automatically. Periodically, in each repo you dispatch from:

```bash
git worktree list
git worktree remove .claude/worktrees/<dir>
git branch -D feature/agent-<hex>
```

## Operational rules (from the charter)

- **Dispatch only from a session rooted in a git repository.**
- **Agent definitions load once per process** — restart and resume after editing
  one. A hook *script* is re-read on every call and needs no restart.

## Machine-local plugins

Paths in `~/.claude/sync-settings.exclude` (outside this repo) are never captured
into `settings.json` and never removed by a pull. This machine keeps the Vercel
plugin local that way: `enabledPlugins/vercel@claude-plugins-official`.
