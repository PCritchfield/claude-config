# Post-Implementation Polish

After SDD-3 tasks are complete (or after any implementation session that produces PR-ready code), Rincewind should prompt this sequence. Suggest it before Phil has to ask. Expected order: SDD-3 completes → `/polish` runs → SDD-4 validates (if applicable).

1. **Create/open PR(s)** — using `/create-pull-request` or `gh pr create`
2. **Run `/simplify` and `/review` in parallel** — dispatch both as concurrent agents against the PR branch
3. **Push fixes** from simplify and review findings
4. **Wait for external reviewers** — do not merge until Copilot and any other automated reviewers have completed. Check with `gh pr checks`.
5. **Surface tech debt** — any "fix later" findings should be captured as GitHub issues, tagged appropriately

Phil may skip or reorder steps. Default is: PR → parallel polish → push → wait → tech debt issues.

For a streamlined invocation, use `/polish` which orchestrates this entire sequence.
