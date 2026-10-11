# claude-workflow with the Watch Council

[claude-workflow](https://github.com/liatrio-labs/claude-workflow) is a Claude Code
plugin for spec-driven delivery: `cw-spec` → `cw-plan` → `cw-dispatch` →
`cw-validate` → `cw-review`, with implementer, verifier and reviewer agents and a
shared task board. This repo enables it (`settings.json`, `enabledPlugins`) and
carries one local fix that makes it compatible with the council's worktree agents.

Status: **under evaluation.** Phil is trialling it to see how it changes day-to-day
work. Nothing here is a final architecture decision.

## How the two fit

They overlap less than they appear to:

| | claude-workflow | Watch Council |
|---|---|---|
| Strength | Orchestration: planning, parallel dispatch, proof verification, task board | Domain doctrine and governance: security, data, IaC, architecture rules; veto order; Rincewind as operator |
| Isolation | `/cw-worktree` creates and provisions worktrees itself | Six implementation agents carry `isolation: worktree` |
| Review | `proof-verifier` re-runs proofs rather than trusting the implementer | Charter Return Path: zero-context review before merge |

The working hypothesis is a split by layer: claude-workflow orchestrates; the council supplies expertise as skills its
implementers and reviewers load, and the veto holders review what it produces.
That is a hypothesis to test, not a plan to execute.

## Setup on a new machine

`install.sh` handles all of it:

1. `settings.json` is synced from this repo, which enables the plugin and registers
   its marketplace (`extraKnownMarketplaces.claude-workflow`).
2. On next start, Claude Code installs the plugin into `~/.claude/plugins/cache/`
   (or asks to, depending on marketplace trust settings — not verified on a clean machine).
3. `scripts/apply-local-patches.sh` applies the local fix below.

Because step 2 happens at Claude Code startup, a brand-new machine needs
`install.sh` run **again after the first launch** for step 3 to find the plugin.
`./verify-drift.sh` reports whether the patch is in place.

## The local patch: WorktreeCreate hook

### The problem

claude-workflow registers a `WorktreeCreate` hook. Any such hook **replaces**
Claude Code's own `git worktree` creation for every worktree it makes — including
every agent with `isolation: worktree`. It cannot defer back to the default: it
must create the worktree and print its path, or creation fails.

The 4.4.1 handler reads payload fields Claude Code does not send:

| The handler reads | Claude Code sends ([docs](https://code.claude.com/docs/en/hooks#worktreecreate-input)) |
|---|---|
| `worktree_name` (required) | `name` |
| `isolation_type` — to choose minimal vs full provisioning | nothing |
| `base_ref` | nothing (the handler defaults to `HEAD`, which is fine) |

So with the plugin enabled, **every isolated agent failed** before starting:
`worktree_name is required in the hook payload`. And with only the name fixed,
every subagent would have been provisioned in *full* mode — writing a
`settings.local.json` with a task-list id into its worktree, which the plugin's
own comments say pollutes the task board.

### The fix

`patches/claude-workflow-4.4.1-worktree-create.patch`, 21 lines:

- read `.worktree_name // .name`
- detect a subagent by `agent_id` if present, otherwise by Claude Code's
  `agent-<hex>` worktree slug, and provision it in minimal mode

### What the payload actually contains

A real subagent payload, captured 2026-10-07:

```
cwd, hook_event_name, name, prompt_id, scratchpad_dir, session_id, transcript_path
```

**No `agent_id`**, even though the docs list it as a common field "to distinguish
subagent hook calls from main-thread calls". The hook fires in the parent's
context, before the subagent exists. The `agent-<hex>` slug is therefore the only
working signal — and it is observed behaviour, not documented. If Claude Code
changes its naming, subagents will quietly fall back to full provisioning. They
will still work; they will just get set up as if they were a user worktree.

### Why it is local, not upstream

It fixes this environment so the plugin can be evaluated. It is not a change
proposed to claude-workflow. (The bug does affect anyone using the plugin with
`claude --worktree`, background sessions, or isolated agents — that is worth an
upstream issue if the evaluation continues.)

### Keeping it applied

Plugin updates replace the cache and silently undo the patch.

```bash
scripts/apply-local-patches.sh          # re-apply if needed (idempotent)
scripts/apply-local-patches.sh --check  # report only; exit 1 if unpatched
./verify-drift.sh                       # includes the check above
```

The script applies the patch **only to version 4.4.1**. On any other version it
reports whether the handler still reads `.worktree_name`:

- if not, the bug is fixed upstream and the patch is no longer needed
- if so, the patch must be re-derived for that version — it is never applied by
  guesswork. Diff the new handler against the 4.4.1 original, carry the same two
  changes across, and save it as `patches/claude-workflow-<version>-worktree-create.patch`

## Known side effect: agent worktrees are not cleaned up

With Claude Code's default worktree creation, a subagent's worktree is removed
automatically when it finishes with no changes. claude-workflow's
`WorktreeRemove` hook is, in its own words, *observability-only* — it never
removes anything. So every isolated agent run leaves a worktree and a
`feature/agent-<hex>` branch behind, clean or not.

Periodically, in each repo you dispatch from:

```bash
git worktree list
git worktree remove .claude/worktrees/<dir>   # for each finished agent
git branch -D feature/agent-<hex>
```

## Operational rules (from the charter)

- **Dispatch only from a session rooted in a git repository.** Elsewhere, spawning
  an isolated agent fails outright rather than running without isolation.
- **Agent definitions load once per process.** After editing one, restart Claude and
  resume the session before dispatching. The *hook script*, by contrast, is read on
  every call — patching it takes effect without a restart.

## Machine-local plugins

Not every plugin belongs in the shared config. Paths listed in
`~/.claude/sync-settings.exclude` (outside this repo) are never captured into
`settings.json` and never removed by a pull. This machine excludes the Vercel
plugin that way:

```
enabledPlugins/vercel@claude-plugins-official
```
