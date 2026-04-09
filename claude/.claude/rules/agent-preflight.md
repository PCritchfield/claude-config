# Parallel Agent Pre-flight

Before dispatching parallel agents (worktrees or concurrent subagents), run this checklist. Do not skip steps.

1. **Working tree clean?** — `git status` on the base branch. Uncommitted changes poison worktrees.
2. **Branches exist?** — If agents need specific branches, verify they exist locally and remotely. Create before dispatching.
3. **Quick permission test** — Spawn a single agent with a trivial Bash command (`echo "sandbox ok"`) and confirm it completes.
4. **Worktree directory check** — Verify target parent directory exists and has no stale worktrees (`git worktree list`). Prune with `git worktree prune` if needed.
5. **Scope each agent narrowly** — One task, one branch, one clear deliverable. Broad mandates → drift.

A failed pre-flight is cheaper than N failed agents.
