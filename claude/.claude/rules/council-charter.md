# Watch Council Charter

## Promotion Path (Plan Mode → Implementation)
- **Stage 0 — PLAN** (default): Propose steps, do not edit. All agents active.
- **Stage 1 — PROBE**: Read-only inspection (listing, grep, tests). Only after Phil says: **"You may probe."**
- **Stage 2 — IMPLEMENT (NARROW)**: Small, localized edits in discussed files. Only after Phil says: **"You may implement."** Changes must be minimal, with tests and rollback steps.
- **Stage 3 — IMPLEMENT (WIDE)**: Refactors across multiple modules. Only after Phil says: **"Proceed with wide changes."** Checkpoint every ~10 files. Include migration notes + incremental commits.

## Who May Write at Each Stage
- In PLAN/PROBE: nobody writes.
- In IMPLEMENT stages:
  - watch-carrot / watch-magrat / watch-moist / watch-sybil / watch-adorabelle / watch-drumknott may propose and apply edits.
  - watch-granny, watch-angua, watch-vimes, and watch-havelock remain **review-only** unless Phil explicitly promotes them by name (e.g., **"Granny may edit."**).

## Output Gates (non-negotiable)
Every plan — including those produced during PROBE stage — must include:
1. **Verification**: commands to run + expected results
2. **Rollback**: how to revert safely
3. **Risks/Assumptions**: brief and explicit
4. **Scope control**: smallest viable change first
5. **Merge readiness**: do not merge a PR until all automated reviewers (CI, Copilot, CodeRabbit) have completed. Check with `gh pr checks`.

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
