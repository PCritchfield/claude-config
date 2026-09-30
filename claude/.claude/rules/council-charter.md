# Watch Council Charter

## Promotion Path (Plan Mode → Implementation)
- **Stage 0 — PLAN** (default): Propose steps, do not edit. All agents active.
- **Stage 1 — PROBE**: Read-only inspection (listing, grep, tests). Only after Phil says: **"You may probe."**
- **Stage 2 — IMPLEMENT (NARROW)**: Small, localized edits in discussed files. Only after Phil says: **"You may implement."** Changes must be minimal, with tests and rollback steps.
- **Stage 3 — IMPLEMENT (WIDE)**: Refactors across multiple modules. Only after Phil says: **"Proceed with wide changes."** Checkpoint every ~10 files. Include migration notes + incremental commits.

## Who May Write at Each Stage
- In PLAN/PROBE: nobody writes to the main checkout.
- The stages above govern writes to the **main checkout**. They cannot govern subagents: an agent definition is a static file, and no promotion phrase rewrites it. So implementation agents are confined by isolation instead.
- **Implementation agents** — watch-carrot / watch-magrat / watch-moist / watch-sybil / watch-adorabelle / watch-drumknott — carry `Write`, `Edit` and `isolation: worktree`. They write only in their own worktree, on their own branch; the harness enforces it. Dispatch them with write tasks only at IMPLEMENT stages. What they produce lands only through the Return Path below.
  - Carrot, Magrat and Drumknott have `Bash` and commit their own branch. Moist, Sybil and Adorabelle do not; Rincewind commits their worktree before integration.
- watch-granny, watch-angua, watch-vimes, and watch-havelock remain **review-only** unless Phil explicitly promotes them by name (e.g., **"Granny may edit."**). Promotion means editing their definition file, not saying a phrase.

## Output Gates (non-negotiable)
Every plan — including those produced during PROBE stage — must include:
1. **Verification**: commands to run + expected results
2. **Rollback**: how to revert safely
3. **Risks/Assumptions**: brief and explicit
4. **Scope control**: smallest viable change first
5. **Merge readiness**: do not merge a PR until all automated reviewers (CI, Copilot, CodeRabbit) have completed. Check with `gh pr checks`.

## Integrating Parallel Work (Return Path)

Worktree isolation prevents agents colliding while they work. It does not decide how their work lands. These rules do. The touch is light by design: Phil is involved only when something is uncertain.

**Every worktree branch gets a zero-context review first.** A fresh agent receives only the diff and the task statement — none of the implementing agent's reasoning — and checks for regressions. An implementer cannot review its own work; a reviewer who has read the implementer's justification is not independent.

**Rincewind may merge without Phil** when the zero-context review finds no regressions **and** either:

1. **No overlap** — the worktree branches touch disjoint files; or
2. **Ordered overlap** — they touch shared files but merge without conflicts, there is a clear priority order (Feat A → Feat B → Feat C), and all tests pass after each merge, applied in that order.

**Stop and escalate to Phil** on any of:
- uncertainty — about scope, intent, correctness, or the priority order itself
- a merge conflict, of any size
- a failing zero-context review or failing tests

Escalate with the standard form, naming the branches involved.

**Scope.** These rules govern merging agent worktree branches into the working branch. They do not relax Output Gate 5: anything reaching `main` still goes through a PR, CI, and the merge-readiness gate.

## Conflict Resolution

### Veto authority (deterministic)
Four agents hold domain veto. Priority order when domains overlap:

1. **watch-angua** — security concerns override when the overlap involves credential exposure, auth bypass, or supply chain risk.
2. **watch-vimes** — data integrity overrides when the overlap involves irreversible data operations, migration safety, or schema correctness.
3. **watch-havelock** — cloud architecture overrides when the overlap involves infrastructure fitness, cost, reliability, or networking.
4. **watch-granny** — application architecture is authoritative in all other design disputes.

Veto is not debate. The veto-holder states their ruling and reason in one sentence.

### Structured dissent
- Dissenting agents file a **minority report**: what they'd do differently and why, in two sentences max.
- Format: **[agent-name] dissents:** [what I'd do instead]. [why it matters].
- Rincewind surfaces minority reports to Phil as a decision packet. Phil resolves. Agents do not debate.

### Escalation
Any agent may escalate with: **"This requires Phil's decision. Reason: [one sentence]."**
Use when: scope/product decisions outside technical remit, risk requires explicit human acceptance, or veto hierarchy cannot resolve.
